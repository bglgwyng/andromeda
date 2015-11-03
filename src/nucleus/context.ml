type renaming = (Name.atom * Name.atom) list

module AtomMap = Map.Make (struct
                      type t = Name.atom
                      let compare = Name.compare_atom
                    end)

module AtomSet = Set.Make (struct
                    type t = Name.atom
                    let compare = Name.compare_atom
                  end)


(* A context is a map which assigns to an atom its type and the dependencies and dependants respectively.
   We can think of it as a directed graph whose vertices are the atoms, labelled by
   the type, and the sets of atoms are the two directions of edges. *)
type t = (Tt.ty * AtomSet.t * AtomSet.t) AtomMap.t

let empty = AtomMap.empty

let print_dependencies s deps ppf =
  if not !Config.print_dependencies || AtomSet.is_empty deps
  then Format.fprintf ppf ""
  else Format.fprintf ppf "@ %s[%t]" s
                      (Print.sequence Name.print_atom "," (AtomSet.elements deps))

let print_entry ppf x (t, deps, revdeps) =
  Format.fprintf ppf "%t : @[<hov>%t@ @[<h>%t@]@[<h>%t@]@]@ "
    (Name.print_atom x)
    (Tt.print_ty [] t)
    (print_dependencies "deps" deps)
    (print_dependencies "revdeps" revdeps)

let print ctx ppf =
  Format.pp_open_vbox ppf 0 ;
  AtomMap.iter (print_entry ppf) ctx ;
  Format.pp_close_box ppf ()

let as_set (ctx : t) = AtomMap.fold (fun x _ s -> AtomSet.add x s) ctx AtomSet.empty

let lookup x (ctx : t) =
  try Some (AtomMap.find x ctx)
  with Not_found -> None

let lookup_ty x ctx =
  match lookup x ctx with None -> None | Some (t, _, _) -> Some t

let cone ctx x (t : Tt.ty) =
  let y = Name.fresh x in
  let ctx = AtomMap.map (fun (u, deps, revdeps) -> (u, deps, AtomSet.add y revdeps)) ctx in
  let ctx = AtomMap.add y (t, as_set ctx, AtomSet.empty) ctx in
  y, ctx


let context_at ctx x =
  let (_,deps,_) = AtomMap.find x ctx in
  let ctx' = AtomSet.fold (fun y ctx' ->
    let (ty,dy,ry) = AtomMap.find y ctx in
      AtomMap.add y (ty,dy,AtomSet.inter ry deps) ctx') deps empty in
  ctx'

let abstract1 ~loc (ctx : t) x =
  match lookup x ctx with
  | None ->
     ctx
  | Some (t, deps, revdeps) ->
     if AtomSet.is_empty revdeps
     then
       let ctx = AtomMap.remove x ctx in
       let ctx = AtomMap.map (fun (t, deps, revdeps) -> (t, deps, AtomSet.remove x revdeps)) ctx in
       ctx
     else
       let revdeps = AtomSet.elements revdeps in
       Error.runtime
         ~loc "cannot abstract %t because %t depend%s on it.\nContext:@ %t"
                     (Name.print_atom x)
                     (Print.sequence (Name.print_atom) "," revdeps)
                     (match revdeps with [_] -> "s" | _ -> "")
                     (print ctx)

let abstract ~loc ctx xs = List.fold_left (abstract1 ~loc) ctx xs

let rename (ctx : t) s =
  let a_s, b_s = List.split s in
  AtomMap.fold
    (fun a (t, deps, revdeps) ctx ->
       let b = try List.assoc a s with Not_found -> a
       and t = Tt.abstract_ty a_s 0 t |> Tt.unabstract_ty b_s 0
       and deps =
         AtomSet.fold
           (fun x deps -> AtomSet.add (try List.assoc x s with Not_found -> x) deps)
           deps AtomSet.empty
       and revdeps =
         AtomSet.fold
           (fun x revdeps -> AtomSet.add (try List.assoc x s with Not_found -> x) revdeps)
           revdeps AtomSet.empty
       in
       let r = AtomMap.add b (t, deps, revdeps) ctx in r)
    ctx
    empty

let refresh ctx =
  let a_s = AtomMap.bindings ctx |> List.map fst in
  let b_s = List.map Name.refresh_atom a_s in
  (rename ctx (List.combine a_s b_s),
   (List.combine b_s a_s))


(** Sort the entries of [ctx] into a list so that all dependencies
    point forward in the list. *)
let topological_sort ctx =
  let rec process x ((handled, _) as handled_ys) =
    if AtomSet.mem x handled
    then handled_ys
    else
      let (_, _, revdeps) = AtomMap.find x ctx in
      let (handled, ys) = AtomSet.fold process revdeps handled_ys  in
      (AtomSet.add x handled, x :: ys)
  in      
  let _, ys = AtomMap.fold (fun x _ -> process x) ctx (AtomSet.empty, []) in
  ys


let mk_eq (Tt.Ty ty) (Tt.Ty ty') = Tt.mk_eq_ty ~loc:Location.unknown Tt.typ ty ty'

(** Extend the context [ctx] such that ctx |- x : ty while keeping track of specific dependency information. *)
let extend ctx deps x ty =
  match lookup x ctx with
  | None ->
    let ctx = AtomMap.mapi (fun y ((ty,dy,ry) as elt) -> if AtomSet.mem y deps then (ty,dy,AtomSet.add x ry) else elt) ctx in
    let ctx = AtomMap.add x (ty, deps, AtomSet.empty) ctx in
    ctx, AtomSet.add x deps
  | Some (ty', deps', revdeps') ->
    if Tt.alpha_equal_ty ty ty'
    then ctx, AtomSet.add x deps'
    else let e = Name.fresh (Name.make "__eq") in
      let deps = AtomSet.union deps deps' in
      let ctx = AtomMap.mapi (fun y ((ty,dy,ry) as elt) -> if AtomSet.mem y deps then (ty,dy,AtomSet.add e ry) else elt) ctx in
      let ctx = AtomMap.add e (mk_eq ty ty', deps, AtomSet.empty) ctx in
      let deps = AtomSet.add e deps in
        ctx, AtomSet.add x deps


(** Make a context stronger than ctx1 and ctx2 while keeping track of dependencies. *)
let join' ctx1 ctx2 =
  let rec joinA ctx f = function
    | [] -> ctx, f
    | x::l -> let ty,deps,_ = AtomMap.find x ctx2 in (* ctx2_deps |- ty : Type *)
      let deps = AtomSet.fold (fun y deps -> AtomSet.union deps (AtomMap.find y f)) deps AtomSet.empty in (* ctx_deps |- ty : Type *)
      let ctx, deps = extend ctx deps x ty in (* ctx_deps |- x : ty *)
      let f = AtomMap.add x deps f in
        joinA ctx f l
    in joinA ctx1 empty (topological_sort ctx2)

let join ctx1 ctx2 = let ctx,_ = join' ctx1 ctx2 in ctx,[]


(** Substitute a variable by a judgment in a context. *)
(* TODO needs heavy debugging *)

let split_around ctx x xrevs =
  let sorted = topological_sort ctx in
  let rec split deps revs = function
    | [] -> deps, List.rev revs
    | y::l -> if Name.eq_atom x y
      then split deps revs l
      else begin if AtomSet.mem y xrevs
        then split deps (y::revs) l
        else let (ty,dy,ry) = AtomMap.find y ctx in
          let ry = AtomSet.fold (fun r ry' -> AtomSet.remove r ry') xrevs (AtomSet.remove x ry) in
          split (AtomMap.add y (ty,dy,ry) deps) revs l
        end
    in split empty [] sorted

let subst_ty ty x e =
  let ty = Tt.abstract_ty [x] 0 ty in
  let ty = Tt.instantiate_ty [e] 0 ty in
    ty



(**
ctx1 |- x : A
ctx2 |- e : A
*)

let substitute ctx1 x (ctx2,e,ty_e) = match lookup x ctx1 with
  | None -> ctx1 (* note that the spec doesn't require us to add ctx2 when x notin ctx1 *)
  | Some (ty,deps,revdeps) ->
    let ctxl1, ctxr1 = split_around ctx1 x revdeps in
    let ctx', f = join' ctx2 ctxl1 in
    let deps_e = as_set ctx2 in

    (* Now ctx'_{deps_e} |- ty == ty_e and |- e : ty_e thus |- e : ty *)
    let rec substA ctx' f = function (* for each processed y from ctx1, ctx'_{f(y)} |- y : subst (ctx1(y)) x e *)
      | [] -> ctx'
      | y::l -> let (ty_y,deps_y,_) = AtomMap.find y ctx1 in
        let deps_y = AtomSet.fold (fun z deps_y -> if Name.eq_atom x z then deps_y else AtomSet.union deps_y (AtomMap.find z f)) deps_y deps_e in
        (* deps_y such that preconditions for the next line *)
        let ctx', deps_y = extend ctx' deps_y y (subst_ty ty_y x e) in
        let f = AtomMap.add y deps_y f in
          substA ctx' f l
      in substA ctx' f ctxr1


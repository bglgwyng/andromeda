(****** Printing routines *****)

open Nucleus_types

(** Forbid the given identifier from being used as a bound variable. *)
let add_forbidden x forbidden = x :: forbidden

let rec ty ?max_level ~forbidden t ppf =
  match t with

  | TypeConstructor (c, args) ->
     constructor ?max_level ~forbidden c args ppf

  | TypeMeta (mv, args) ->
     meta ?max_level ~forbidden mv args ppf

and term ?max_level ~forbidden e ppf =
  match e with
  | TermAtom {atom_name=x; _} ->
     Name.print_atom x ppf

  | TermBound k -> Name.print_debruijn forbidden k ppf

  | TermConstructor (c, args) ->
     constructor ?max_level ~forbidden c args ppf

  | TermMeta (mv, args) ->
     meta ?max_level ~forbidden mv args ppf

  | TermConvert (e, _, _) -> term ~forbidden ?max_level e ppf

and eq_type ?max_level ~forbidden (EqType (_asmp, t1, t2)) ppf =
  (* TODO: print _asmp? *)
  Print.print
    ?max_level
    ~at_level:Level.eq
    ppf
    "%t@ %s@ %t"
    (ty ~forbidden t1)
    (Print.char_equal ())
    (ty ~forbidden t2)

and eq_term ?max_level ~forbidden (EqTerm (_asmp, e1, e2, t)) ppf =
  (* TODO: print _asmp? *)
  Print.print
    ?max_level
    ~at_level:Level.eq
    ppf
    "%t@ %s@ %t@ :@ %t"
    (term ~forbidden e1)
    (Print.char_equal ())
    (term ~forbidden e2)
    (ty ~forbidden t)

and meta :
  type a . ?max_level:Level.t -> forbidden:(Name.ident list)
            -> a meta -> is_term list -> Format.formatter -> unit
  = fun ?max_level ~forbidden {meta_name;_} args ppf ->
  match args with
  | [] ->
     Name.print_meta ~parentheses:true meta_name ppf
  | _::_ ->
     Print.print ~at_level:Level.meta ?max_level ppf "%t@ %t"
    (Name.print_meta meta_name)
    (Print.sequence (term ~max_level:Level.meta_arg ~forbidden) "" args) ;

and constructor ?max_level ~forbidden c args ppf =
  match args with
  | [] ->
     Name.print_ident ~parentheses:true c ppf
  | _::_ ->
     Print.print ~at_level:Level.constructor ?max_level ppf "%t@ %t"
       (Name.print_ident c)
       (Print.sequence (argument ~forbidden) "" args) ;

and abstraction
   : 'b . (bound -> 'b -> bool) ->
          (?max_level:Level.t -> forbidden:(Name.ident list) -> 'b -> Format.formatter -> unit) ->
          ?max_level:Level.t ->
          forbidden:(Name.ident list) ->
          'b abstraction ->
          Format.formatter -> unit
  = fun occurs_v print_v ?max_level ~forbidden abstr ppf ->
  let rec fold forbidden abstr ppf =
    match abstr with

    | NotAbstract v ->
          print_v ~max_level:Level.abstraction_body ~forbidden v ppf

    | Abstract (x, u, abstr) ->
       let x =
         (if Occurs.abstraction occurs_v 0 abstr then
            Name.refresh forbidden x
          else
            Name.anonymous ())
       in
       Print.print ppf "%t@ " (binder ~forbidden (x, u)) ;
       let forbidden = add_forbidden x forbidden in
       fold forbidden abstr ppf
  in
  match abstr with
  | NotAbstract v -> print_v ?max_level ~forbidden v ppf
  | Abstract _ -> Print.print ~at_level:Level.abstraction ?max_level ppf "%t" (fold forbidden abstr)

and argument ~forbidden arg ppf =
  match arg with
  | ArgumentIsType abstr ->
     abstraction Occurs.is_type ty ~max_level:Level.constructor_arg ~forbidden abstr ppf
  | ArgumentIsTerm abstr ->
     abstraction Occurs.is_term term ~max_level:Level.constructor_arg ~forbidden abstr ppf
  | ArgumentEqType abstr ->
     abstraction Occurs.eq_type eq_type ~max_level:Level.constructor_arg ~forbidden abstr ppf
  | ArgumentEqTerm abstr ->
     abstraction Occurs.eq_term eq_term ~max_level:Level.constructor_arg ~forbidden abstr ppf


and binder ~forbidden (x,t) ppf =
  Print.print ppf "{%t@ :@ %t}"
    (Name.print_ident ~parentheses:true x)
    (ty ~max_level:Level.binder ~forbidden t)


(** Printing judgements *)

let is_type ?max_level ~forbidden t ppf =
  Print.print ?max_level ~at_level:Level.jdg ppf
              "@[<hov 2>%s@ %t@ type@]"
              (Print.char_vdash ())
              (ty ~max_level:Level.highest ~forbidden t)

let is_term ?max_level ~forbidden e ppf =
  Print.print ?max_level ~at_level:Level.jdg ppf
              "@[<hov 2>%s@ %t@]"
              (Print.char_vdash ())
              (term ~max_level:Level.highest ~forbidden e)

let eq_type ?max_level ~forbidden eq ppf =
  Print.print ?max_level ~at_level:Level.jdg ppf
              "@[<hov 2>%s@ %t@]"
              (Print.char_vdash ())
              (eq_type ~max_level:Level.highest ~forbidden eq)

let eq_term ?max_level ~forbidden eq ppf =
  Print.print ?max_level ~at_level:Level.jdg ppf
              "@[<hov 2>%s@ %t@]"
              (Print.char_vdash ())
              (eq_term ~max_level:Level.highest ~forbidden eq)

let is_type_abstraction ?max_level ~forbidden abstr ppf =
  (* TODO: print invisible assumptions, or maybe the entire context *)
  abstraction Occurs.is_type is_type ?max_level ~forbidden abstr ppf

let is_term_abstraction ?max_level ~forbidden abstr ppf =
  (* TODO: print invisible assumptions, or maybe the entire context *)
  abstraction Occurs.is_term is_term ?max_level ~forbidden abstr ppf

let eq_type_abstraction ?max_level ~forbidden abstr ppf =
  (* TODO: print invisible assumptions, or maybe the entire context *)
  abstraction Occurs.eq_type eq_type ?max_level ~forbidden abstr ppf

let eq_term_abstraction ?max_level ~forbidden abstr ppf =
  (* TODO: print invisible assumptions, or maybe the entire context *)
  abstraction Occurs.eq_term eq_term ?max_level ~forbidden abstr ppf



let error ~forbidden err ppf =
  let open Nucleus_types in
  match err with
  | InvalidInstantiation -> Format.fprintf ppf "invalid instantiation"
  | InvalidAbstraction -> Format.fprintf ppf "invalid abstraction"
  | TooFewArguments -> Format.fprintf ppf "too few arguments"
  | TooManyArguments -> Format.fprintf ppf "too many arguments"
  | TermExpected -> Format.fprintf ppf "term expected"
  | TypeExpected -> Format.fprintf ppf "type expected"
  | ExtraAssumptions -> Format.fprintf ppf "extra assumptions"
  | InvalidApplication -> Format.fprintf ppf "invalid application"
  | InvalidArgument -> Format.fprintf ppf "invalid argument"
  | IsTypeExpected -> Format.fprintf ppf "type argument expected"
  | IsTermExpected -> Format.fprintf ppf "term argument expected"
  | EqTypeExpected -> Format.fprintf ppf "type equality argument expected"
  | EqTermExpected -> Format.fprintf ppf "term equality argument expected"
  | AbstractionExpected -> Format.fprintf ppf "abstraction expected"
  | InvalidSubstitution -> Format.fprintf ppf "invalid substutition"
  | InvalidCongruence -> Format.fprintf ppf "invalid congruence argument"

  | InvalidConvert (t1, t2) ->
     Format.fprintf ppf "trying to convert something at@ %t@ using an equality on@ %t@"
                    (ty ~forbidden t1) (ty ~forbidden t2)

  | AlphaEqualTypeMismatch (t1, t2) ->
     Format.fprintf ppf "the types@ %t@ and@ %t@ should be alpha equal"
                    (ty ~forbidden t1) (ty ~forbidden t2)

  | AlphaEqualTermMismatch (e1, e2) ->
     Format.fprintf ppf "the terms@ %t@ and@ %t@ should be alpha equal"
                    (term ~forbidden e1) (term ~forbidden e2)

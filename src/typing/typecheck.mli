(** [toplevel env c] checks that toplevel command [c] is well typed and updates the environment accordingly. *)
val toplevel : Tyenv.t -> Desugared.toplevel -> Tyenv.t * Syntax.toplevel

(** Typecheck commands that were loaded from a file *)
val toplevels : Tyenv.t -> Desugared.toplevel list -> Tyenv.t * Syntax.toplevel list

(** The initial typing context with built-in definitions *)
val initial_context : Tyenv.t

(** The commands which need to be executed in the empty runtime environment to obtain a runtime environment counter-part to
    [initial_context] *)
val initial_commands : Syntax.toplevel list

module Builtin :
sig
  val nil : Ident.t * Mlty.ty list * Mlty.ty
  val cons : Ident.t * Mlty.ty list * Mlty.ty

  val none : Ident.t * Mlty.ty list * Mlty.ty
  val some : Ident.t * Mlty.ty list * Mlty.ty

  val mlless : Ident.t * Mlty.ty list * Mlty.ty
  val mlequal : Ident.t * Mlty.ty list * Mlty.ty
  val mlgreater : Ident.t * Mlty.ty list * Mlty.ty

  val mlfalse : Ident.t * Mlty.ty list * Mlty.ty
  val mltrue : Ident.t * Mlty.ty list * Mlty.ty

  val equal_type : Ident.t * (Mlty.ty list * Mlty.ty)
  val coerce : Ident.t * (Mlty.ty list * Mlty.ty)

end

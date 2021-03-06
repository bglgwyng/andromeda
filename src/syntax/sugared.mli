(** Sugared input syntax

    The abstract syntax of input as typed by the user. At this stage
    there is no distinction between computations, expressions, and types.
    However, we define type aliases for these for better readability.
    There are no de Bruijn indices either. *)

type 'a located = 'a Location.located

(** Bound variables are de Bruijn indices *)
type bound = int

type ml_ty = ml_ty' located
and ml_ty' =
  | ML_Arrow of ml_ty * ml_ty
  | ML_Prod of ml_ty list
  | ML_TyApply of Name.path * ml_ty list
  | ML_Handler of ml_ty * ml_ty
  | ML_Ref of ml_ty
  | ML_Exn
  | ML_Judgement
  | ML_Boundary
  | ML_Derivation
  | ML_String
  | ML_Anonymous

type ml_schema = ml_schema' located
and ml_schema' = ML_Forall of Name.t option list * ml_ty

(** Annotation of an ML-function argument *)
type arg_annotation =
  | Arg_annot_none
  | Arg_annot_ty of ml_ty

(** Annotation of a let-binding *)
type let_annotation =
  | Let_annot_none
  | Let_annot_schema of ml_schema


(** Sugared patterns *)
type pattern = pattern' located
and pattern' =
  | Patt_Anonymous
  | Patt_Var of Name.t
  | Patt_Path of Name.path
  | Patt_MLAscribe of pattern * ml_ty
  | Patt_As of pattern * pattern
  | Patt_GenAtom of pattern
  | Patt_IsType of pattern
  | Patt_IsTerm of pattern * pattern
  | Patt_EqType of pattern * pattern
  | Patt_EqTerm of pattern * pattern * pattern
  | Patt_Abstraction of (Name.t option * pattern option) list * pattern
  | Patt_BoundaryIsType
  | Patt_BoundaryIsTerm of pattern
  | Patt_BoundaryEqType of pattern * pattern
  | Patt_BoundaryEqTerm of pattern * pattern * pattern
  | Patt_Constructor of Name.path * pattern list
  | Patt_List of pattern list
  | Patt_Tuple of pattern list
  | Patt_String of string

(** Sugared terms *)
type comp = comp' located
and comp' =
  | Name of Name.path
  | Function of pattern list * comp
  | Handler of handle_case list
  | Try of comp * handle_case list
  | With of comp * comp
  | Raise of comp
  | List of comp list
  | Tuple of comp list
  | Match of comp * match_case list
  | Let of let_clause list  * comp
  | LetRec of letrec_clause list * comp
  | MLAscribe of comp * ml_schema
  | Lookup of comp
  | Update of comp * comp
  | Ref of comp
  | Sequence of comp * comp
  | Fresh of Name.t option * comp
  | Meta of Name.t option
  | BoundaryAscribe of comp * comp
  | TypeAscribe of comp * comp
  | EqTypeAscribe of comp * comp * comp
  | EqTermAscribe of comp * comp * comp * comp
  | Abstract of (Name.t * comp option) list * comp
  | AbstractAtom of comp * comp
  | Substitute of comp * comp list
  | Derive of premise list * comp
  | RuleApply of comp * comp list
  | Spine of comp * comp list
  | String of string
  | Congruence of comp * comp * comp list
  | Context of comp
  | Convert of comp * comp
  | Occurs of comp * comp
  | Natural of comp
  | MLBoundaryIsType
  | MLBoundaryIsTerm of comp
  | MLBoundaryEqType of comp * comp
  | MLBoundaryEqTerm of comp * comp * comp

and let_clause =
  | Let_clause_ML of (Name.t * pattern list) option * let_annotation * comp
  | Let_clause_tt of Name.t option * comp * comp
  | Let_clause_patt of pattern * let_annotation * comp

and letrec_clause = Name.t * pattern * pattern list * let_annotation * comp

(** Handler cases *)
and handle_case =
  | CaseVal of match_case (* val p -> c *)
  | CaseOp of Name.path * match_op_case (* op p1 ... pn -> c *)
  | CaseExc of exception_case (* raise p -> c *)

and match_case = pattern * comp option * comp

and exception_case = match_case

and match_op_case = pattern list * pattern option * comp

and top_operation_case = Name.path * match_op_case

(** The local context of a premise to a rule. *)
and local_context = (Name.t * comp) list

(** A premise to a rule *)
and premise = premise' located
and premise' = Premise of Name.t option * local_context * comp

type ml_tydef =
  | ML_Sum of (Name.t * ml_ty list) list
  | ML_Alias of ml_ty

(** Sugared toplevel commands *)
type toplevel = toplevel' located
and toplevel' =
  | Rule of Name.t * premise list * comp
  | DefMLTypeAbstract of Name.t * Name.t option list
  | DefMLType of (Name.t * (Name.t option list * ml_tydef)) list
  | DefMLTypeRec of (Name.t * (Name.t option list * ml_tydef)) list
  | DeclOperation of Name.t * (ml_ty list * ml_ty)
  | DeclException of Name.t * ml_ty option
  | DeclExternal of Name.t * ml_schema * string
  | TopLet of let_clause list
  | TopLetRec of letrec_clause list
  | TopWith of top_operation_case list
  | TopComputation of comp
  | Verbosity of int
  | Require of Name.t list
  | Include of Name.path
  | Open of Name.path
  | TopModule of Name.t * toplevel list

(** The abstract syntax of Andromedan type theory (TT). *)

type bound = int

type is_type =
  | TypeMeta of meta_any * is_term list
  | TypeConstructor of Ident.t * argument list

and is_term =
  | TermBoundVar of bound (* de Bruijm index of a bound variable *)
  | TermAtom of is_atom (* a free variable *)
  | TermMeta of meta_any * is_term list (* term meta-variable applied to arguments *)
  | TermConstructor of Ident.t * argument list (* term constructor applied to arguments *)
  | TermConvert of is_term * assumption * is_type (* term conversion *)

and eq_type = EqType of assumption * is_type * is_type

(* In a term equality [EqTerm (asmp, e1, e2, t)] we maintain the invariant
   that [e1] and [e2] are *not* term conversions. Instead, we put such term
   conversions back in when a term equality is inverted, as necessary. *)
and eq_term = EqTerm of assumption * is_term * is_term * is_type

and is_atom = { atom_nonce : Nonce.t ; atom_type : is_type }

and argument =
  | Arg_NotAbstract of judgement
  | Arg_Abstract of Name.t * argument

and meta = { meta_nonce : Nonce.t ; meta_boundary : boundary_abstraction }

and meta_any =
  | MetaFree of meta
  | MetaBound of bound

and assumption =
  { free_var : is_type Nonce.map
  ; free_meta : boundary_abstraction Nonce.map
  ; bound_var : Bound_set.t
  ; bound_meta : Bound_set.t
  }

and 'a abstraction =
  | NotAbstract of 'a
  | Abstract of Name.t * is_type * 'a abstraction

and judgement =
  | JudgementIsType of is_type
  | JudgementIsTerm of is_term
  | JudgementEqType of eq_type
  | JudgementEqTerm of eq_term

and judgement_abstraction = judgement abstraction

and is_type_boundary = unit
and is_term_boundary = is_type
and eq_type_boundary = is_type * is_type
and eq_term_boundary = is_term * is_term * is_type

and boundary =
  | BoundaryIsType of is_type_boundary
  | BoundaryIsTerm of is_term_boundary
  | BoundaryEqType of eq_type_boundary
  | BoundaryEqTerm of eq_term_boundary

and boundary_abstraction = boundary abstraction

type 'a rule =
  | Conclusion of 'a
  | Premise of meta * 'a rule

type primitive = boundary rule

type derivation = judgement rule

(* A partial rule application *)
type 'a rule_application =
  | RapDone of 'a
  | RapMore of boundary_abstraction * (judgement_abstraction -> 'a rule_application)

type signature = primitive Ident.map

type is_term_abstraction = is_term abstraction
type is_type_abstraction = is_type abstraction
type eq_type_abstraction = eq_type abstraction
type eq_term_abstraction = eq_term abstraction

(** Stumps are used to construct and invert judgements. The [form_XYZ]
   functions take a stump and construct a judgement from it,
   whereas the [invert_XYZ] functions do the opposite. We can think of stumps
   as "stumps", i.e., the lowest level of a derivation tree. *)

type stump_is_type =
  | Stump_TypeConstructor of Ident.t * judgement_abstraction list
  | Stump_TypeMeta of meta * is_term list

type stump_is_term =
  | Stump_TermAtom of is_atom
  | Stump_TermConstructor of Ident.t * judgement_abstraction list
  | Stump_TermMeta of meta * is_term list
  | Stump_TermConvert of is_term * eq_type

type stump_eq_type =
  | Stump_EqType of assumption * is_type * is_type

type stump_eq_term =
  | Stump_EqTerm of assumption * is_term * is_term * is_type

type 'a stump_abstraction =
  | Stump_NotAbstract of 'a
  | Stump_Abstract of is_atom * 'a abstraction

(** A stump for inverting two abstractions at the same time. *)
type ('a, 'b) stumps_abstraction =
  | Stumps_NotAbstract of 'a * 'b
  | Stumps_Abstract of is_atom * 'a abstraction * 'b abstraction

type congruence_argument =
  | CongrIsType of is_type abstraction * is_type abstraction * eq_type abstraction
  | CongrIsTerm of is_term abstraction * is_term abstraction * eq_term abstraction
  | CongrEqType of eq_type abstraction * eq_type abstraction
  | CongrEqTerm of eq_term abstraction * eq_term abstraction

(* Sometimes we work with meta-variables in their _de Bruijn index_ order, i.e.,
   as a list whose first element is de Bruijn index 0, and sometimes we work in
   the _constructor_ order, i.e., in the order of premises to a rule. These
   are reverse from each other. We have found it to be quite error-prone to
   keep track of which order any given list might be, so we use some abstract
   types to reduce the possibility of further bugs.

   Used by module Indices
*)
type 'a indices = 'a list

type error =
  | InvalidInstantiation
  | InvalidAbstraction
  | TooFewArguments
  | TooManyArguments
  | IsTermExpected
  | IsTypeExpected
  | IsTypeBoundaryExpected
  | IsTermBoundaryExpected
  | ExtraAssumptions
  | InvalidApplication
  | InvalidArgument
  | ArgumentExpected of boundary
  | AbstractionExpected
  | InvalidSubstitution
  | InvalidCongruence
  | AlphaEqualTypeMismatch of is_type * is_type
  | AlphaEqualTermMismatch of is_term * is_term
  | InvalidConvert of is_type * is_type
  | AtomInRule

exception Error of error

type print_environment = {
  forbidden : Name.set ;
  debruijn_var : Name.t list ;
  debruijn_meta : Name.t list ;
  opens : Path.set
}

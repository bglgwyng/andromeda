(** The abstract syntax of Andromedan type theory (TT). *)

type bound = int

type is_type =
  | TypeMeta of is_type_meta * is_term list
  | TypeConstructor of Ident.t * judgement_abstraction list

and is_term =
  | TermBound of bound
  | TermAtom of is_atom
  | TermMeta of is_term_meta * is_term list
  | TermConstructor of Ident.t * judgement_abstraction list
  | TermConvert of is_term * assumption * is_type

and eq_type = EqType of assumption * is_type * is_type

and eq_term = EqTerm of assumption * is_term * is_term * is_type

and is_atom = { atom_nonce : Nonce.t ; atom_type : is_type }

and 't meta = { meta_nonce : Nonce.t ; meta_type : 't }

and is_type_meta = is_type_boundary abstraction meta
and is_term_meta = is_term_boundary abstraction meta
and eq_type_meta = eq_type_boundary abstraction meta
and eq_term_meta = eq_term_boundary abstraction meta
and judgement_meta = boundary_abstraction meta

and assumption =
  { free : is_type Nonce.map
  ; meta : boundary_abstraction Nonce.map
  ; bound : Bound_set.t }

and 'a abstraction =
  | NotAbstract of 'a
  | Abstract of is_atom * 'a abstraction

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

type rule_application_status =
  { rap_arguments : judgement_abstraction list (* the arguments collected so far *)
  ; rap_boundary : boundary_abstraction (* the boundary of the next argument *)
  ; rap_premises : Rule.boundary_abstraction list (* the remaining premises to be applied *)
  ; rap_constructor : judgement_abstraction list -> judgement (* the function which makes the final result *)
  }

(* A partial rule application *)
type rule_application =
  | RapDone of judgement
  | RapMore of rule_application_status

type signature = Rule.rule Ident.map

type is_term_abstraction = is_term abstraction
type is_type_abstraction = is_type abstraction
type eq_type_abstraction = eq_type abstraction
type eq_term_abstraction = eq_term abstraction

(** Stumps are used to construct and invert judgements. The [form_XYZ]
   functions take a stump and construct a judgement from it,
   whereas the [invert_XYZ] functions do the opposite. We can think of stumps
   as "stumps", i.e., the lowest level of a derivation tree. *)

type nonrec stump_is_type =
  | Stump_TypeConstructor of Ident.t * judgement_abstraction list
  | Stump_TypeMeta of is_type_meta * is_term list

and stump_is_term =
  | Stump_TermAtom of is_atom
  | Stump_TermConstructor of Ident.t * judgement_abstraction list
  | Stump_TermMeta of is_term_meta * is_term list
  | Stump_TermConvert of is_term * eq_type

and stump_eq_type =
  | Stump_EqType of assumption * is_type * is_type

and stump_eq_term =
  | Stump_EqTerm of assumption * is_term * is_term * is_type

and 'a stump_abstraction =
  | Stump_NotAbstract of 'a
  | Stump_Abstract of is_atom * 'a abstraction

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
  | TermExpected
  | TypeExpected
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

exception Error of error

type print_environment = {
  forbidden : Name.set ;
  debruijn : Name.t list ;
  opens : Path.set
}

(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(** Locations are a refinement of RTL pseudo-registers, used to reflect
  the results of register allocation (file [Allocation]). *)

Require Import Coqlib.
Require Import Maps.
Require Import AST.
Require Import Values.

(** * Representation of locations *)

(** A location is either a processor register or (an abstract designation of)
  a slot in the activation record of the current function. *)

(** ** Machine registers *)

(** The following type defines the machine registers that can be referenced
  as locations.  These include:
- Integer registers that can be allocated to RTL pseudo-registers ([Rxx]).
- Floating-point registers that can be allocated to RTL pseudo-registers 
  ([Fxx]).
- Three integer registers, not allocatable, reserved as temporaries for
  spilling and reloading ([ITx]).
- Three float registers, not allocatable, reserved as temporaries for
  spilling and reloading ([FTx]).

  The type [mreg] does not include special-purpose machine registers
  such as the stack pointer and the condition codes. *)

Inductive mreg: Set :=
  (** Allocatable integer regs *)
  | R3: mreg  | R4: mreg  | R5: mreg  | R6: mreg
  | R7: mreg  | R8: mreg  | R9: mreg  | R10: mreg
  | R13: mreg | R14: mreg | R15: mreg | R16: mreg
  | R17: mreg | R18: mreg | R19: mreg | R20: mreg
  | R21: mreg | R22: mreg | R23: mreg | R24: mreg
  | R25: mreg | R26: mreg | R27: mreg | R28: mreg
  | R29: mreg | R30: mreg | R31: mreg
  (** Allocatable float regs *)
  | F1: mreg  | F2: mreg  | F3: mreg  | F4: mreg
  | F5: mreg  | F6: mreg  | F7: mreg  | F8: mreg
  | F9: mreg  | F10: mreg | F14: mreg | F15: mreg
  | F16: mreg | F17: mreg | F18: mreg | F19: mreg
  | F20: mreg | F21: mreg | F22: mreg | F23: mreg
  | F24: mreg | F25: mreg | F26: mreg | F27: mreg
  | F28: mreg | F29: mreg | F30: mreg | F31: mreg
  (** Integer temporaries *)
  | IT1: mreg (* R11 *) | IT2: mreg (* R12 *) | IT3: mreg (* R0 *)
  (** Float temporaries *)
  | FT1: mreg (* F11 *) | FT2: mreg (* F12 *) | FT3: mreg (* F0 *).

Lemma mreg_eq: forall (r1 r2: mreg), {r1 = r2} + {r1 <> r2}.
Proof. decide equality. Qed.

Definition mreg_type (r: mreg): typ :=
  match r with
  | R3 => Tint  | R4 => Tint  | R5 => Tint  | R6 => Tint
  | R7 => Tint  | R8 => Tint  | R9 => Tint  | R10 => Tint
  | R13 => Tint | R14 => Tint | R15 => Tint | R16 => Tint
  | R17 => Tint | R18 => Tint | R19 => Tint | R20 => Tint
  | R21 => Tint | R22 => Tint | R23 => Tint | R24 => Tint
  | R25 => Tint | R26 => Tint | R27 => Tint | R28 => Tint
  | R29 => Tint | R30 => Tint | R31 => Tint
  | F1 => Tfloat  | F2 => Tfloat  | F3 => Tfloat  | F4 => Tfloat
  | F5 => Tfloat  | F6 => Tfloat  | F7 => Tfloat  | F8 => Tfloat
  | F9 => Tfloat  | F10 => Tfloat | F14 => Tfloat | F15 => Tfloat
  | F16 => Tfloat | F17 => Tfloat | F18 => Tfloat | F19 => Tfloat
  | F20 => Tfloat | F21 => Tfloat | F22 => Tfloat | F23 => Tfloat
  | F24 => Tfloat | F25 => Tfloat | F26 => Tfloat | F27 => Tfloat
  | F28 => Tfloat | F29 => Tfloat | F30 => Tfloat | F31 => Tfloat
  | IT1 => Tint | IT2 => Tint | IT3 => Tint
  | FT1 => Tfloat | FT2 => Tfloat | FT3 => Tfloat
  end.

Open Scope positive_scope.

Module IndexedMreg <: INDEXED_TYPE.
  Definition t := mreg.
  Definition eq := mreg_eq.
  Definition index (r: mreg): positive :=
    match r with
    | R3 => 1  | R4 => 2  | R5 => 3  | R6 => 4
    | R7 => 5  | R8 => 6  | R9 => 7  | R10 => 8
    | R13 => 9 | R14 => 10 | R15 => 11 | R16 => 12
    | R17 => 13 | R18 => 14 | R19 => 15 | R20 => 16
    | R21 => 17 | R22 => 18 | R23 => 19 | R24 => 20
    | R25 => 21 | R26 => 22 | R27 => 23 | R28 => 24
    | R29 => 25 | R30 => 26 | R31 => 27
    | F1 => 28  | F2 => 29  | F3 => 30  | F4 => 31
    | F5 => 32  | F6 => 33  | F7 => 34  | F8 => 35
    | F9 => 36  | F10 => 37 | F14 => 38 | F15 => 39
    | F16 => 40 | F17 => 41 | F18 => 42 | F19 => 43
    | F20 => 44 | F21 => 45 | F22 => 46 | F23 => 47
    | F24 => 48 | F25 => 49 | F26 => 50 | F27 => 51
    | F28 => 52 | F29 => 53 | F30 => 54 | F31 => 55
    | IT1 => 56 | IT2 => 57 | IT3 => 58
    | FT1 => 59 | FT2 => 60 | FT3 => 61
    end.
  Lemma index_inj:
    forall r1 r2, index r1 = index r2 -> r1 = r2.
  Proof.
    destruct r1; destruct r2; simpl; intro; discriminate || reflexivity.
  Qed.
End IndexedMreg.

(** ** Slots in activation records *)

(** A slot in an activation record is designated abstractly by a kind,
  a type and an integer offset.  Three kinds are considered:
- [Local]: these are the slots used by register allocation for 
  pseudo-registers that cannot be assigned a hardware register.
- [Incoming]: used to store the parameters of the current function
  that cannot reside in hardware registers, as determined by the 
  calling conventions.
- [Outgoing]: used to store arguments to called functions that 
  cannot reside in hardware registers, as determined by the 
  calling conventions. *)

Inductive slot: Set :=
  | Local: Z -> typ -> slot
  | Incoming: Z -> typ -> slot
  | Outgoing: Z -> typ -> slot.

(** Morally, the [Incoming] slots of a function are the [Outgoing]
slots of its caller function.

The type of a slot indicates how it will be accessed later once mapped to
actual memory locations inside a memory-allocated activation record:
as 32-bit integers/pointers (type [Tint]) or as 64-bit floats (type [Tfloat]).

The offset of a slot, combined with its type and its kind, identifies
uniquely the slot and will determine later where it resides within the
memory-allocated activation record.  Offsets are always positive.

Conceptually, slots will be mapped to four non-overlapping memory areas
within activation records:
- The area for [Local] slots of type [Tint].  The offset is interpreted
  as a 4-byte word index.
- The area for [Local] slots of type [Tfloat].  The offset is interpreted
  as a 8-byte word index.  Thus, two [Local] slots always refer either
  to the same memory chunk (if they have the same types and offsets)
  or to non-overlapping memory chunks (if the types or offsets differ).
- The area for [Outgoing] slots.  The offset is a 4-byte word index.
  Unlike [Local] slots, the PowerPC calling conventions demand that
  integer and float [Outgoing] slots reside in the same memory area.
  Therefore, [Outgoing Tint 0] and [Outgoing Tfloat 0] refer to
  overlapping memory chunks and cannot be used simultaneously: one will
  lose its value when the other is assigned.  We will reflect this
  overlapping behaviour in the environments mapping locations to values
  defined later in this file.
- The area for [Incoming] slots.  Same structure as the [Outgoing] slots.
*)

Definition slot_type (s: slot): typ :=
  match s with
  | Local ofs ty => ty
  | Incoming ofs ty => ty
  | Outgoing ofs ty => ty
  end.

Lemma slot_eq: forall (p q: slot), {p = q} + {p <> q}.
Proof.
  assert (typ_eq: forall (t1 t2: typ), {t1 = t2} + {t1 <> t2}).
  decide equality.
  generalize zeq; intro.
  decide equality.
Qed.

Open Scope Z_scope.

Definition typesize (ty: typ) : Z :=
  match ty with Tint => 1 | Tfloat => 2 end.

Lemma typesize_pos:
  forall (ty: typ), typesize ty > 0.
Proof.
  destruct ty; compute; auto.
Qed.

(** ** Locations *)

(** Locations are just the disjoint union of machine registers and
  activation record slots. *)

Inductive loc : Set :=
  | R: mreg -> loc
  | S: slot -> loc.

Module Loc.

  Definition type (l: loc) : typ :=
    match l with
    | R r => mreg_type r
    | S s => slot_type s
    end.

  Lemma eq: forall (p q: loc), {p = q} + {p <> q}.
  Proof.
    decide equality. apply mreg_eq. apply slot_eq.
  Qed.

(** As mentioned previously, two locations can be different (in the sense
  of the [<>] mathematical disequality), yet denote 
  overlapping memory chunks within the activation record.
  Given two locations, three cases are possible:
- They are equal (in the sense of the [=] equality)
- They are different and non-overlapping.
- They are different but overlapping.

  The second case (different and non-overlapping) is characterized 
  by the following [Loc.diff] predicate.
*)
  Definition diff (l1 l2: loc) : Prop :=
    match l1, l2 with
    | R r1, R r2 => r1 <> r2
    | S (Local d1 t1), S (Local d2 t2) =>
        d1 <> d2 \/ t1 <> t2
    | S (Incoming d1 t1), S (Incoming d2 t2) =>
        d1 + typesize t1 <= d2 \/ d2 + typesize t2 <= d1
    | S (Outgoing d1 t1), S (Outgoing d2 t2) =>
        d1 + typesize t1 <= d2 \/ d2 + typesize t2 <= d1
    | _, _ =>
        True
    end.

  Lemma same_not_diff:
    forall l, ~(diff l l).
  Proof.
    destruct l; unfold diff; try tauto.
    destruct s.
    tauto.
    generalize (typesize_pos t); omega. 
    generalize (typesize_pos t); omega. 
  Qed.

  Lemma diff_not_eq:
    forall l1 l2, diff l1 l2 -> l1 <> l2.
  Proof.
    unfold not; intros. subst l2. elim (same_not_diff l1 H).
  Qed.

  Lemma diff_sym:
    forall l1 l2, diff l1 l2 -> diff l2 l1.
  Proof.
    destruct l1; destruct l2; unfold diff; auto.
    destruct s; auto.
    destruct s; destruct s0; intuition auto.
  Qed.

(** [Loc.overlap l1 l2] returns [false] if [l1] and [l2] are different and
  non-overlapping, and [true] otherwise: either [l1 = l2] or they partially 
  overlap. *)

  Definition overlap_aux (t1: typ) (d1 d2: Z) : bool :=
    if zeq d1 d2 then true else
    match t1 with
    | Tint => false
    | Tfloat => if zeq (d1 + 1) d2 then true else false
    end.    

  Definition overlap (l1 l2: loc) : bool :=
    match l1, l2 with
    | S (Incoming d1 t1), S (Incoming d2 t2) =>
        overlap_aux t1 d1 d2 || overlap_aux t2 d2 d1
    | S (Outgoing d1 t1), S (Outgoing d2 t2) =>
        overlap_aux t1 d1 d2 || overlap_aux t2 d2 d1
    | _, _ => false
    end.

  Lemma overlap_aux_true_1:
    forall d1 t1 d2 t2,
    overlap_aux t1 d1 d2 = true ->
    ~(d1 + typesize t1 <= d2 \/ d2 + typesize t2 <= d1).
  Proof.
    intros until t2.
    generalize (typesize_pos t1); intro.
    generalize (typesize_pos t2); intro.
    unfold overlap_aux.
    case (zeq d1 d2).
    intros. omega.
    case t1. intros; discriminate.
    case (zeq (d1 + 1) d2); intros.
    subst d2. simpl. omega.
    discriminate.
  Qed.

  Lemma overlap_aux_true_2:
    forall d1 t1 d2 t2,
    overlap_aux t2 d2 d1 = true ->
    ~(d1 + typesize t1 <= d2 \/ d2 + typesize t2 <= d1).
  Proof.
    intros. generalize (overlap_aux_true_1 d2 t2 d1 t1 H).
    tauto.
  Qed.

  Lemma overlap_not_diff:
    forall l1 l2, overlap l1 l2 = true -> ~(diff l1 l2).
  Proof.
    unfold overlap, diff; destruct l1; destruct l2; intros; try discriminate.
    destruct s; discriminate.
    destruct s; destruct s0; try discriminate.
    elim (orb_true_elim _ _ H); intro.
    apply overlap_aux_true_1; auto.
    apply overlap_aux_true_2; auto.
    elim (orb_true_elim _ _ H); intro.
    apply overlap_aux_true_1; auto.
    apply overlap_aux_true_2; auto.
  Qed.

  Lemma overlap_aux_false_1:
    forall t1 d1 t2 d2,
    overlap_aux t1 d1 d2 || overlap_aux t2 d2 d1 = false ->
    d1 + typesize t1 <= d2 \/ d2 + typesize t2 <= d1.
  Proof.
    intros until d2. intro OV. 
    generalize (orb_false_elim _ _ OV). intro OV'. elim OV'.
    unfold overlap_aux. 
    case (zeq d1 d2); intro.
    intros; discriminate.
    case (zeq d2 d1); intro.
    intros; discriminate.
    case t1; case t2; simpl.
    intros; omega.
    case (zeq (d2 + 1) d1); intros. discriminate. omega.
    case (zeq (d1 + 1) d2); intros. discriminate. omega.
    case (zeq (d1 + 1) d2); intros H1 H2. discriminate. 
    case (zeq (d2 + 1) d1); intros. discriminate. omega.
  Qed.

  Lemma non_overlap_diff:
    forall l1 l2, l1 <> l2 -> overlap l1 l2 = false -> diff l1 l2.
  Proof.
    intros. unfold diff; destruct l1; destruct l2. 
    congruence.
    auto.
    destruct s; auto.
    destruct s; destruct s0; auto. 
    case (zeq z z0); intro.
    compare t t0; intro.
    congruence. tauto. tauto.
    apply overlap_aux_false_1. exact H0.
    apply overlap_aux_false_1. exact H0.
  Qed.

(** We now redefine some standard notions over lists, using the [Loc.diff]
  predicate instead of standard disequality [<>].

  [Loc.notin l ll] holds if the location [l] is different from all locations
  in the list [ll]. *)

  Fixpoint notin (l: loc) (ll: list loc) {struct ll} : Prop :=
    match ll with
    | nil => True
    | l1 :: ls => diff l l1 /\ notin l ls
    end.

  Lemma notin_not_in:
    forall l ll, notin l ll -> ~(In l ll).
  Proof.
    unfold not; induction ll; simpl; intros.
    auto.
    elim H; intros. elim H0; intro. 
    subst l. exact (same_not_diff a H1).
    auto.
  Qed.

(** [Loc.disjoint l1 l2] is true if the locations in list [l1]
  are different from all locations in list [l2]. *)

  Definition disjoint (l1 l2: list loc) : Prop :=
    forall x1 x2, In x1 l1 -> In x2 l2 -> diff x1 x2.

  Lemma disjoint_cons_left:
    forall a l1 l2,
    disjoint (a :: l1) l2 -> disjoint l1 l2.
  Proof.
    unfold disjoint; intros. auto with coqlib.    
  Qed.
  Lemma disjoint_cons_right:
    forall a l1 l2,
    disjoint l1 (a :: l2) -> disjoint l1 l2.
  Proof.
    unfold disjoint; intros. auto with coqlib.    
  Qed.

  Lemma disjoint_sym:
    forall l1 l2, disjoint l1 l2 -> disjoint l2 l1.
  Proof.
    unfold disjoint; intros. apply diff_sym; auto.
  Qed.

  Lemma in_notin_diff:
    forall l1 l2 ll, notin l1 ll -> In l2 ll -> diff l1 l2.
  Proof.
    induction ll; simpl; intros.
    elim H0.
    elim H0; intro. subst a. tauto. apply IHll; tauto.
  Qed.

  Lemma notin_disjoint:
    forall l1 l2,
    (forall x, In x l1 -> notin x l2) -> disjoint l1 l2.
  Proof.
    unfold disjoint; induction l1; intros.
    elim H0. 
    elim H0; intro.
    subst x1. eapply in_notin_diff. apply H. auto with coqlib. auto.
    eapply IHl1; eauto. intros. apply H. auto with coqlib.
  Qed.

  Lemma disjoint_notin:
    forall l1 l2 x, disjoint l1 l2 -> In x l1 -> notin x l2.
  Proof.
    unfold disjoint; induction l2; simpl; intros.
    auto.
    split. apply H. auto. tauto.
    apply IHl2. intros. apply H. auto. tauto. auto.
  Qed.

(** [Loc.norepet ll] holds if the locations in list [ll] are pairwise
  different. *)

  Inductive norepet : list loc -> Prop :=
  | norepet_nil:
      norepet nil
  | norepet_cons:
      forall hd tl, notin hd tl -> norepet tl -> norepet (hd :: tl).

  Definition no_overlap (l1 l2 : list loc) :=
   forall r, In r l1 -> forall s, In s l2 ->  r = s \/ Loc.diff r s.

End Loc.

(** * Mappings from locations to values *)

(** The [Locmap] module defines mappings from locations to values,
  used as evaluation environments for the semantics of the [LTL] 
  and [LTLin] intermediate languages.  *)

Set Implicit Arguments.

Module Locmap.

  Definition t := loc -> val.

  Definition init (x: val) : t := fun (_: loc) => x.

  Definition get (l: loc) (m: t) : val := m l.

  (** The [set] operation over location mappings reflects the overlapping
      properties of locations: changing the value of a location [l]
      invalidates (sets to [Vundef]) the locations that partially overlap
      with [l].  In other terms, the result of [set l v m]
      maps location [l] to value [v], locations that overlap with [l]
      to [Vundef], and locations that are different (and non-overlapping)
      from [l] to their previous values in [m].  This is apparent in the
      ``good variables'' properties [Locmap.gss] and [Locmap.gso]. *)

  Definition set (l: loc) (v: val) (m: t) : t :=
    fun (p: loc) =>
      if Loc.eq l p then v else if Loc.overlap l p then Vundef else m p.

  Lemma gss: forall l v m, (set l v m) l = v.
  Proof.
    intros. unfold set. case (Loc.eq l l); tauto.
  Qed.

  Lemma gso: forall l v m p, Loc.diff l p -> (set l v m) p = m p.
  Proof.
    intros. unfold set. case (Loc.eq l p); intro.
    subst p. elim (Loc.same_not_diff _ H). 
    caseEq (Loc.overlap l p); intro.
    elim (Loc.overlap_not_diff _ _ H0 H).
    auto.
  Qed.

End Locmap.

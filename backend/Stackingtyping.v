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

(** Type preservation for the [Stacking] pass. *)

Require Import Coqlib.
Require Import Maps.
Require Import Errors.
Require Import Integers.
Require Import AST.
Require Import Op.
Require Import Locations.
Require Import Conventions.
Require Import Linear.
Require Import Lineartyping.
Require Import Mach.
Require Import Machtyping.
Require Import Bounds.
Require Import Stacking.
Require Import Stackingproof.

(** We show that the Mach code generated by the [Stacking] pass
  is well-typed if the original LTLin code is. *)

Definition wt_instrs (k: Mach.code) : Prop :=
  forall i, In i k -> wt_instr i.

Lemma wt_instrs_cons:
  forall i k,
  wt_instr i -> wt_instrs k -> wt_instrs (i :: k).
Proof.
  unfold wt_instrs; intros. elim H1; intro.
  subst i0; auto. auto.
Qed.

Section TRANSL_FUNCTION.

Variable f: Linear.function.
Let fe := make_env (function_bounds f).
Variable tf: Mach.function.
Hypothesis TRANSF_F: transf_function f = OK tf.

Lemma wt_fold_right:
  forall (A: Set) (f: A -> code -> code) (k: code) (l: list A),
  (forall x k', In x l -> wt_instrs k' -> wt_instrs (f x k')) ->
  wt_instrs k ->
  wt_instrs (List.fold_right f k l).
Proof.
  induction l; intros; simpl.
  auto.
  apply H. apply in_eq. apply IHl. 
  intros. apply H. auto with coqlib. auto. 
  auto. 
Qed.

Lemma wt_save_callee_save_int:
  forall k,
  wt_instrs k ->
  wt_instrs (save_callee_save_int fe k).
Proof.
  intros. unfold save_callee_save_int, save_callee_save_regs.
  apply wt_fold_right; auto.
  intros. unfold save_callee_save_reg. 
  case (zlt (index_int_callee_save x) (fe_num_int_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  apply wt_Msetstack. apply int_callee_save_type; auto.
  auto.
Qed.

Lemma wt_save_callee_save_float:
  forall k,
  wt_instrs k ->
  wt_instrs (save_callee_save_float fe k).
Proof.
  intros. unfold save_callee_save_float, save_callee_save_regs.
  apply wt_fold_right; auto.
  intros. unfold save_callee_save_reg. 
  case (zlt (index_float_callee_save x) (fe_num_float_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  apply wt_Msetstack. apply float_callee_save_type; auto.
  auto.
Qed.

Lemma wt_restore_callee_save_int:
  forall k,
  wt_instrs k ->
  wt_instrs (restore_callee_save_int fe k).
Proof.
  intros. unfold restore_callee_save_int, restore_callee_save_regs.
  apply wt_fold_right; auto.
  intros. unfold restore_callee_save_reg.
  case (zlt (index_int_callee_save x) (fe_num_int_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  constructor. apply int_callee_save_type; auto.
  auto.
Qed.

Lemma wt_restore_callee_save_float:
  forall k,
  wt_instrs k ->
  wt_instrs (restore_callee_save_float fe k).
Proof.
  intros. unfold restore_callee_save_float, restore_callee_save_regs.
  apply wt_fold_right; auto.
  intros. unfold restore_callee_save_reg.
  case (zlt (index_float_callee_save x) (fe_num_float_callee_save fe)); intro.
  apply wt_instrs_cons; auto.
  constructor. apply float_callee_save_type; auto.
  auto.
Qed.

Lemma wt_save_callee_save:
  forall k,
  wt_instrs k -> wt_instrs (save_callee_save fe k).
Proof.
  intros. unfold save_callee_save.
  apply wt_save_callee_save_int. apply wt_save_callee_save_float. auto.
Qed.

Lemma wt_restore_callee_save:
  forall k,
  wt_instrs k -> wt_instrs (restore_callee_save fe k).
Proof.
  intros. unfold restore_callee_save.
  apply wt_restore_callee_save_int. apply wt_restore_callee_save_float. auto.
Qed.

Lemma wt_transl_instr:
  forall instr k,
  In instr f.(Linear.fn_code) ->
  Lineartyping.wt_instr f instr ->
  wt_instrs k ->
  wt_instrs (transl_instr fe instr k).
Proof.
  intros.
  generalize (instr_is_within_bounds f instr H H0); intro BND.
  destruct instr; unfold transl_instr; inv H0; simpl in BND.
  (* getstack *)
  destruct BND.
  destruct s; simpl in *; apply wt_instrs_cons; auto;
  constructor; auto.
  (* setstack *)
  destruct s.
  apply wt_instrs_cons; auto. apply wt_Msetstack. auto. 
  auto.
  apply wt_instrs_cons; auto. apply wt_Msetstack. auto. 
  (* op, move *)
  simpl. apply wt_instrs_cons. constructor; auto. auto.
  (* op, others *)
  apply wt_instrs_cons; auto.
  constructor. 
  destruct o; simpl; congruence.
  rewrite H6. destruct o; reflexivity || congruence.
  (* load *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  rewrite H4. destruct a; reflexivity.
  (* store *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  rewrite H4. destruct a; reflexivity.
  (* call *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* tailcall *)
  apply wt_restore_callee_save. apply wt_instrs_cons; auto.
  constructor; auto.
  destruct s0; auto. rewrite H5; auto.
  (* alloc *)
  apply wt_instrs_cons; auto. constructor. 
  (* label *)
  apply wt_instrs_cons; auto.
  constructor.
  (* goto *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* cond *)
  apply wt_instrs_cons; auto.
  constructor; auto.
  (* return *)
  apply wt_restore_callee_save. apply wt_instrs_cons. constructor. auto.
Qed.

End TRANSL_FUNCTION.

Lemma wt_transf_function:
  forall f tf, 
  transf_function f = OK tf ->
  Lineartyping.wt_function f ->
  wt_function tf.
Proof.
  intros. 
  generalize H; unfold transf_function.
  case (zlt (Linear.fn_stacksize f) 0); intro.
  intros; discriminate.
  case (zlt (- Int.min_signed) (fe_size (make_env (function_bounds f)))); intro.
  intros; discriminate. intro EQ.
  generalize (unfold_transf_function f tf H); intro.
  assert (fn_framesize tf = fe_size (make_env (function_bounds f))).
    subst tf; reflexivity.
  constructor.
  change (wt_instrs (fn_code tf)).
  rewrite H1; simpl; unfold transl_body. 
  apply wt_save_callee_save; auto. 
  unfold transl_code. apply wt_fold_right. 
  intros. eapply wt_transl_instr; eauto. 
  red; intros. elim H3.
  subst tf; simpl; auto.
  rewrite H2. eapply size_pos; eauto.
  rewrite H2. eapply size_no_overflow; eauto.
Qed.

Lemma wt_transf_fundef:
  forall f tf, 
  Lineartyping.wt_fundef f ->
  transf_fundef f = OK tf ->
  wt_fundef tf.
Proof.
  intros f tf WT. inversion WT; subst.
  simpl; intros; inversion H. constructor.
  unfold transf_fundef, transf_partial_fundef.
  caseEq (transf_function f0); simpl; try congruence.
  intros tfn TRANSF EQ. inversion EQ; subst tf.
  constructor; eapply wt_transf_function; eauto. 
Qed.

Lemma program_typing_preserved:
  forall (p: Linear.program) (tp: Mach.program),
  transf_program p = OK tp ->
  Lineartyping.wt_program p ->
  Machtyping.wt_program tp.
Proof.
  intros; red; intros.
  generalize (transform_partial_program_function transf_fundef p i f H H1).
  intros [f0 [IN TRANSF]].
  apply wt_transf_fundef with f0; auto.
  eapply H0; eauto.
Qed.

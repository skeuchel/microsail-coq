(******************************************************************************)
(* Copyright (c) 2019 Steven Keuchel, Dominique Devriese                      *)
(* All rights reserved.                                                       *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(*    this list of conditions and the following disclaimer.                   *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation and/or other materials provided with the distribution.    *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR         *)
(* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF     *)
(* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING       *)
(* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         *)
(* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               *)
(******************************************************************************)

From Coq Require Import
     Arith.PeanoNat
     Bool.Bool
     Classes.Morphisms
     Classes.Morphisms_Prop
     Classes.Morphisms_Relations
     Classes.RelationClasses
     Lists.List
     Relations.Relation_Definitions
     Relations.Relation_Operators
     Strings.String
     ZArith.ZArith.
From Coq Require
     Vector.
From Equations Require Import Equations.

From MicroSail Require Import
     Sep.Spec
     Syntax.

From stdpp Require
     base finite list option.

Import CtxNotations.
Import EnvNotations.
Import ListNotations.

Set Implicit Arguments.

Delimit Scope mutator_scope with mut.
Delimit Scope smut_scope with smut.

Module Mutators
       (termkit : TermKit)
       (progkit : ProgramKit termkit)
       (assertkit : AssertionKit termkit progkit)
       (symcontractkit : SymbolicContractKit termkit progkit assertkit).

  Export symcontractkit.

  Declare Scope modal.
  Delimit Scope modal with modal.

  Import Entailment.

  Record World : Type :=
    MkWorld
      { wctx :> LCtx;
        wco  : PathCondition wctx;
      }.

  Record Acc (w1 w2 : World) : Type :=
    MkAcc
      { wsub :> Sub w1 w2;
        went :  wco w2 ⊢ subst (wco w1) wsub;
      }.

  Notation "w1 ⊒ w2" := (Acc w1 w2) (at level 80).

  Local Obligation Tactic := idtac.
  Program Definition wrefl {w} : w ⊒ w :=
    {| wsub := sub_id w |}.
  Next Obligation.
    intros ?. now rewrite subst_sub_id.
  Qed.

  Program Definition wtrans {w0 w1 w2} : w0 ⊒ w1 -> w1 ⊒ w2 -> w0 ⊒ w2 :=
    fun ω01 ω12 => {| wsub := subst (T := Sub _) ω01 ω12 |}.
  Next Obligation.
    intros *.
    rewrite subst_sub_comp.
    intros ι2 Hpc2.
    rewrite inst_subst.
    apply (went ω01 (inst (T := Sub _) ω12 ι2)).
    rewrite <- inst_subst.
    apply (went ω12 ι2 Hpc2).
  Defined.

  Definition wnil : World := @MkWorld ctx_nil nil.
  Definition wsnoc (w : World) (b : 𝑺 * Ty) : World :=
    @MkWorld (wctx w ▻ b) (subst (wco w) sub_wk1).
  Definition wformula (w : World) (f : Formula w) : World :=
    @MkWorld (wctx w) (cons f (wco w)).
  Definition wsubst (w : World) x {σ} {xIn : x :: σ ∈ w} (t : Term (w - (x :: σ)) σ) : World.
  Proof.
    apply (@MkWorld (ctx_remove xIn)).
    refine (subst (wco w) _).
    apply sub_single.
    apply t.
  Defined.
  Global Arguments wsubst w x {σ xIn} t.

  Program Definition wsnoc_sup {w : World} {b : 𝑺 * Ty} : w ⊒ wsnoc w b :=
    MkAcc w (wsnoc w b) sub_wk1 _.
  Next Obligation.
  Proof.
    intros w b ι Hpc. apply Hpc.
  Qed.

  Program Definition wsnoc_sub {w1 w2 : World} (ω12 : w1 ⊒ w2) (b : 𝑺 * Ty) (t : Term w2 (snd b)) :
    wsnoc w1 b ⊒ w2 :=
    MkAcc (wsnoc w1 b) w2 (sub_snoc ω12 b t) _.
  Next Obligation.
    unfold entails.
    intros w1 w2 ω12 [x σ] t ι2 Hpc2.
    cbn - [inst].
    rewrite ?inst_subst.
    rewrite inst_sub_snoc.
    rewrite inst_sub_wk1.
    rewrite <- inst_subst.
    now apply (went ω12).
  Qed.

  Definition wcat (w : World) (Δ : LCtx) : World :=
    @MkWorld (wctx w ▻▻ Δ) (subst (wco w) (sub_cat_left Δ)).

  Program Definition wcat_sub {w1 w2} (ω12 : w1 ⊒ w2) {Δ : LCtx} (ζ : Sub Δ w2) :
    wcat w1 Δ ⊒ w2 := {| wsub := wsub ω12 ►► ζ |}.
  Next Obligation.
  Proof.
    intros * ι Hpc. unfold wcat. cbn.
    rewrite <- subst_sub_comp.
    rewrite sub_comp_cat_left.
    now apply went.
  Qed.

  Program Definition wformula_sup {w : World} {f : Formula w} : w ⊒ wformula w f :=
    MkAcc w (wformula w f) (sub_id (wctx w)) _.
  Next Obligation.
  Proof.
    intros w f ι.
    rewrite subst_sub_id. cbn.
    rewrite inst_pathcondition_cons.
    now intros [].
  Qed.

  Definition wformulas (w : World) (fmls : List Formula w) : World :=
    @MkWorld (wctx w) (app fmls (wco w)).

  Program Definition wformulas_sup (w : World) (fmls : List Formula w) :
    w ⊒ wformulas w fmls :=
    MkAcc w (wformulas w fmls) (sub_id (wctx w)) _.
  Next Obligation.
  Proof.
    intros w fmls ι. cbn. rewrite inst_subst, inst_sub_id.
    rewrite inst_pathcondition_app; intuition.
  Qed.

  Program Definition wred_sup {w : World} b (t : Term w (snd b)) :
    wsnoc w b ⊒ w :=
    MkAcc (wsnoc w b) w (sub_snoc (sub_id w) b t) _.
  Next Obligation.
  Proof.
    intros w b t ι Hpcι; cbn.
    now rewrite ?inst_subst, inst_sub_snoc, inst_sub_id, inst_sub_wk1.
  Qed.

  Program Definition wsubst_sup {w : World} {x σ} {xIn : x :: σ ∈ w} {t : Term (w - (x :: σ)) σ} :
    w ⊒ wsubst w x t :=
    MkAcc w (wsubst w x t) (sub_single xIn t) _.
  Next Obligation.
  Proof.
    intros w x σ xIn t ι Hpc. apply Hpc.
  Qed.

  Program Definition wacc_snoc {w0 w1 : World} (ω01 : w0 ⊒ w1) (b : 𝑺 * Ty) :
    wsnoc w0 b ⊒ wsnoc w1 b :=
    MkAcc (wsnoc w0 b) (wsnoc w1 b) (sub_up1 ω01) _.
  Next Obligation.
    intros ? ? ? ?.
    unfold wsnoc in *.
    cbn [wco wctx] in *.
    rewrite <- subst_sub_comp.
    rewrite sub_comp_wk1_comm.
    rewrite subst_sub_comp.
    apply proper_subst_entails.
    apply went.
  Qed.

  Program Definition wacc_formula {w0 w1} (ω01 : w0 ⊒ w1) (fml : Formula w0) :
    wformula w0 fml ⊒ wformula w1 (subst fml ω01) :=
    MkAcc (MkWorld (cons fml (wco w0))) (MkWorld (cons (subst fml ω01) (wco w1))) ω01 _.
  Next Obligation.
    intros ? ? ? ? ι.
    unfold wformula in *.
    cbn [wco wctx] in *.
    repeat rewrite ?inst_pathcondition_cons, ?inst_subst.
    intuition. rewrite <- inst_subst.
    now apply went.
  Qed.

  Notation WList A := (fun w : World => list (A w)).
  Notation STerm σ := (fun Σ => Term Σ σ).

  Module WorldInstance.

    Record WInstance (w : World) : Set :=
      MkWInstance
        { ιassign :> SymInstance w;
          ιvalid  : instpc (wco w) ιassign;
        }.

    Program Definition winstance_formula {w} (ι : WInstance w) (fml : Formula w) (p : inst (A := Prop) fml ι) :
      WInstance (wformula w fml) :=
      {| ιassign := ι; |}.
    Next Obligation.
    Proof.
      intros. cbn.
      apply inst_pathcondition_cons. split; auto.
      apply ιvalid.
    Qed.

    Program Definition winstance_snoc {w} (ι : WInstance w) {b : 𝑺 * Ty} (v : Lit (snd b)) :
      WInstance (wsnoc w b) :=
      {| ιassign := env_snoc (ιassign ι) b v; |}.
    Next Obligation.
    Proof.
      intros. unfold wsnoc. cbn [wctx wco].
      rewrite inst_subst, inst_sub_wk1.
      apply ιvalid.
    Qed.

    (* Fixpoint winstance_cat {Σ} (ι : WInstance Σ) {Δ} (ιΔ : SymInstance Δ) : *)
    (*   WInstance (wcat Σ Δ). *)
    (* Proof. *)
    (*   destruct ιΔ; cbn. *)
    (*   - apply ι. *)
    (*   - apply winstance_snoc. *)
    (*     apply winstance_cat. *)
    (*     apply ι. *)
    (*     apply ιΔ. *)
    (*     apply db. *)
    (* Defined. *)

    Program Definition winstance_subst {w} (ι : WInstance w) {x σ} {xIn : x :: σ ∈ w}
      (t : Term (w - (x :: σ)) σ) (p : inst t (env_remove (x :: σ) (ιassign ι) xIn) = env_lookup (ιassign ι) xIn) :
      WInstance (wsubst w x t) :=
      @MkWInstance (wsubst w x t) (env_remove _ (ιassign ι) xIn) _.
    Next Obligation.
      intros. cbn. rewrite inst_subst.
      rewrite inst_sub_single.
      apply ιvalid.
      apply p.
    Qed.

    Program Definition instacc {w0 w1} (ω01 : w0 ⊒ w1) (ι : WInstance w1) : WInstance w0 :=
       {| ιassign := inst (wsub ω01) (ιassign ι) |}.
    Next Obligation.
    Proof.
      intros w0 w1 ω01 ι.
      rewrite <- inst_subst.
      apply went.
      apply ιvalid.
    Qed.

  End WorldInstance.

  Definition TYPE : Type := World -> Type.
  Bind Scope modal with TYPE.
  Definition Valid (A : TYPE) : Type :=
    forall w, A w.
  Definition Impl (A B : TYPE) : TYPE :=
    fun w => A w -> B w.
  Definition Box (A : TYPE) : TYPE :=
    fun w0 => forall w1, w0 ⊒ w1 -> A w1.
  Definition Snoc (A : TYPE) (b : 𝑺 * Ty) : TYPE :=
    fun w => A (wsnoc w b).
  Definition Forall {I : Type} (A : I -> TYPE) : TYPE :=
    fun w => forall i : I, A i w.
  Definition Cat (A : TYPE) (Δ : LCtx) : TYPE :=
    fun w => A (wcat w Δ).

  Module ModalNotations.

    Notation "⊢ A" := (Valid A%modal) (at level 100).
    Notation "A -> B" := (Impl A%modal B%modal) : modal.
    Notation "□ A" := (Box A%modal) (at level 9, format "□ A", right associativity) : modal.
    Notation "⌜ A ⌝" := (fun (w : World) => Const A%type w) (at level 0, format "⌜ A ⌝") : modal.
    Notation "'∀' x .. y , P " :=
      (Forall (fun x => .. (Forall (fun y => P%modal)) ..))
        (at level 99, x binder, y binder, right associativity)
      : modal.

  End ModalNotations.
  Import ModalNotations.
  Open Scope modal.

  Definition K {A B} :
    ⊢ □(A -> B) -> (□A -> □B) :=
    fun w0 f a w1 ω01 =>
      f w1 ω01 (a w1 ω01).
  Definition T {A} :
    ⊢ □A -> A :=
    fun w0 a => a w0 wrefl.
  Definition four {A} :
    ⊢ □A -> □□A :=
    fun w0 a w1 ω01 w2 ω12 =>
      a w2 (wtrans ω01 ω12).
  Global Arguments four : simpl never.

  (* faster version of (four _ sub_wk1) *)
  (* Definition four_wk1 {A} : *)
  (*   ⊢ □A -> ∀ b, Snoc (□A) b := *)
  (*   fun w0 a b w1 ω01 => a w1 (env_tail ω01). *)
  (* Arguments four_wk1 {A Σ0} pc0 a b [Σ1] ζ01 : rename. *)

  Definition valid_box {A} :
    (⊢ A) -> (⊢ □A) :=
    fun a w0 w1 ω01 => a w1.
  Global Arguments valid_box {A} a {w} [w1].

  Definition map_box {A B} (f : ⊢ A -> B) : ⊢ □A -> □B :=
    fun w0 a w1 ω01 => f w1 (a w1 ω01).

  Notation "f <$> a" := (map_box f a) (at level 40, left associativity).
  Notation "f <*> a" := (K f a) (at level 40, left associativity).

  Definition PROP : TYPE :=
    fun _ => Prop.

  Definition comp {A B C} :
    ⊢ (B -> C) -> (A -> B) -> (A -> C) :=
    fun w0 => Basics.compose.

  Class Persistent (A : TYPE) (* `{LogicalRelation.LR A} *) : Type :=
    persist     : ⊢ A -> □A.
      (* persist_lr  : forall w0 (a : A w0) w1 (ω01 : w0 ⊒ w1), *)
      (*     LogicalRelation.lr ω01 a (persist a ω01); *)
      (* persist_dcl : *)
      (*   forall w (a : A w), *)
      (*     LogicalRelation.dcl (persist a) *)
  (* Global Arguments Persistent A {_}. *)

  Global Instance persist_subst {A} `{Subst A} : Persistent A :=
    fun w0 x w1 ω01 => subst x ω01.

  Notation persist__term t :=
    (@persist (STerm _) (@persist_subst (fun Σ => Term Σ _) (@SubstTerm _)) _ t).

  Inductive Debug {B} (b : B) (P : Prop) : Prop :=
  | debug (p : P).

  Section Obligations.

    Inductive Obligation {Σ} (msg : Message Σ) (fml : Formula Σ) (ι : SymInstance Σ) : Prop :=
    | obligation (p : inst fml ι : Prop).

  End Obligations.

  Section MultiSubs.

    Inductive MultiSub (w : World) : World -> Type :=
    | multisub_id        : MultiSub w w
    | multisub_cons {w' x σ} (xIn : (x::σ) ∈ w) (t : Term (wctx w - (x::σ)) σ)
                    (ν : MultiSub (wsubst w x t) w')
                    : MultiSub w w'.

    Global Arguments multisub_id {_}.
    Global Arguments multisub_cons {_ _} x {_ _} t ν.

    Fixpoint multisub_app {w1 w2 w3} (ν12 : MultiSub w1 w2) : MultiSub w2 w3 -> MultiSub w1 w3 :=
      match ν12 with
      | multisub_id           => fun ν => ν
      | multisub_cons x t ν12 => fun ν => multisub_cons x t (multisub_app ν12 ν)
      end.

    Fixpoint wmultisub_sup {w1 w2} (ν : MultiSub w1 w2) : w1 ⊒ w2 :=
      match ν with
      | multisub_id         => wrefl
      | multisub_cons _ _ ν => wtrans wsubst_sup (wmultisub_sup ν)
      end.

    Fixpoint sub_multishift {w1 w2} (ζ : MultiSub w1 w2) : Sub w2 w1 :=
      match ζ with
      | multisub_id         => sub_id _
      | multisub_cons x t ζ => subst (sub_multishift ζ) (sub_shift _)
      end.

    Fixpoint inst_multisub {w0 w1} (ζ : MultiSub w0 w1) (ι : SymInstance w0) : Prop :=
      match ζ with
      | multisub_id => True
      | @multisub_cons _ Σ' x σ xIn t ζ0 =>
        let ι' := env_remove (x :: σ) ι xIn in
        env_lookup ι xIn = inst t ι' /\ inst_multisub ζ0 ι'
      end.

    Lemma inst_multi {w1 w2 : World} (ι1 : SymInstance w1) (ζ : MultiSub w1 w2) :
      inst_multisub ζ ι1 ->
      inst (wsub (wmultisub_sup ζ)) (inst (sub_multishift ζ) ι1) = ι1.
    Proof.
      intros Hζ. induction ζ; cbn - [subst].
      - now rewrite ?inst_sub_id.
      - cbn in Hζ. destruct Hζ as [? Hζ].
        rewrite <- inst_sub_shift in Hζ.
        rewrite ?inst_subst.
        rewrite IHζ; auto. rewrite inst_sub_shift.
        now rewrite inst_sub_single.
    Qed.

    Lemma inst_multishift_multisub {w1 w2 : World} (ι2 : SymInstance w2) (ν : MultiSub w1 w2) :
      inst (sub_multishift ν) (inst (wsub (wmultisub_sup ν)) ι2) = ι2.
    Proof.
      induction ν; cbn - [subst].
      - now rewrite ?inst_sub_id.
      - rewrite <- inst_subst.
        rewrite sub_comp_assoc.
        rewrite inst_subst.
        rewrite <- sub_comp_assoc.
        rewrite sub_comp_shift_single.
        rewrite inst_subst, inst_sub_id.
        apply IHν.
    Qed.

    (* Forward entailment *)
    Lemma multishift_entails {w0 w1} (ν : MultiSub w0 w1) (ι0 : SymInstance w0) :
      inst_multisub ν ι0 ->
      instpc (wco w0) ι0 ->
      instpc (wco w1) (inst (sub_multishift ν) ι0).
    Proof.
      induction ν; cbn.
      - cbn. rewrite inst_sub_id. auto.
      - intros [Heqx Heq'] Hpc0.
        rewrite inst_subst, inst_sub_shift.
        apply IHν; cbn; auto.
        rewrite ?inst_subst, ?inst_sub_single; auto.
    Qed.

    Lemma inst_multisub_inst_sub_multi {w0 w1} (ζ01 : MultiSub w0 w1) (ι1 : SymInstance w1) :
      inst_multisub ζ01 (inst (wsub (wmultisub_sup ζ01)) ι1).
    Proof.
        induction ζ01; cbn - [subst]; auto.
        rewrite <- inst_sub_shift.
        rewrite <- ?inst_subst.
        rewrite <- inst_lookup.
        rewrite lookup_sub_comp.
        rewrite lookup_sub_single_eq.
        rewrite <- subst_sub_comp.
        rewrite <- sub_comp_assoc.
        rewrite sub_comp_shift_single.
        rewrite sub_comp_id_left.
        split; auto.
    Qed.

    Lemma inst_multisub_app {w0 w1 w2} (ν01 : MultiSub w0 w1) (ν12 : MultiSub w1 w2) (ι0 : SymInstance w0) :
      inst_multisub (multisub_app ν01 ν12) ι0 <->
      inst_multisub ν01 ι0 /\ inst_multisub ν12 (inst (sub_multishift ν01) ι0).
    Proof.
      induction ν01; cbn.
      - rewrite inst_sub_id; intuition.
      - rewrite ?inst_subst, ?inst_sub_shift. split.
        + intros (Heq & Hwp). apply IHν01 in Hwp. now destruct Hwp.
        + intros ([Heq Hν01] & Hwp). split; auto. apply IHν01; auto.
    Qed.

    Lemma sub_multishift_app {w0 w1 w2} (ν01 : MultiSub w0 w1) (ν12 : MultiSub w1 w2) :
      sub_multishift (multisub_app ν01 ν12) =
      subst (sub_multishift ν12) (sub_multishift ν01).
    Proof.
      induction ν01; cbn.
      - now rewrite sub_comp_id_right.
      - now rewrite IHν01, sub_comp_assoc.
    Qed.

    Lemma wmultisub_sup_app {w0 w1 w2} (ν01 : MultiSub w0 w1) (ν12 : MultiSub w1 w2) :
      wsub (wmultisub_sup (multisub_app ν01 ν12)) =
      subst (wsub (wmultisub_sup ν01)) (wsub (wmultisub_sup ν12)).
    Proof.
      induction ν01; cbn - [SubstEnv].
      - now rewrite sub_comp_id_left.
      - rewrite <- subst_sub_comp. now f_equal.
    Qed.

  End MultiSubs.

  Module Solver.

    Equations(noeqns) simplify_formula_bool {Σ} (t : Term Σ ty_bool) (k : List Formula Σ) : option (List Formula Σ) :=
    | term_var ς                | k := Some (cons (formula_bool (term_var ς)) k);
    | term_lit _ b              | k := if b then Some k else None;
    | term_binop op t1 t2       | k := Some (cons (formula_bool (term_binop op t1 t2)) k);
    | term_not t                | k := Some (cons (formula_bool (term_not t)) k);
    | @term_projtup _ _ t n _ p | k := Some (cons (formula_bool (@term_projtup _ _ t n _ p)) k).

    Definition simplify_formula_eqb {Σ σ} (t1 t2 : Term Σ σ) (k : List Formula Σ) : option (List Formula Σ) :=
      if Term_eqb t1 t2
      then Some k
      else Some (cons (formula_eq t1 t2) k).

    Equations(noeqns) simplify_formula_eq {Σ σ} (t1 t2 : Term Σ σ) (k : List Formula Σ) : option (List Formula Σ) :=
    | term_lit ?(σ) l1     | term_lit σ l2     | k => if Lit_eqb σ l1 l2 then Some k else None;
    | term_inr _           | term_inl _        | k => None;
    | term_inl _           | term_inr _        | k => None;
    | term_inl t1          | term_inl t2       | k => simplify_formula_eq t1 t2 k;
    | term_inr t1          | term_inr t2       | k => simplify_formula_eq t1 t2 k;
    | term_record ?(R) ts1 | term_record R ts2 | k => Some (formula_eqs_nctx ts1 ts2 ++ k);
    | t1                   | t2                | k => simplify_formula_eqb t1 t2 k.

    Definition simplify_formula {Σ} (fml : Formula Σ) (k : List Formula Σ) : option (List Formula Σ) :=
      match fml with
      | formula_bool t    => simplify_formula_bool t k
      | formula_prop ζ P  => Some (cons fml k)
      | formula_eq t1 t2  => simplify_formula_eq t1 t2 k
      | formula_neq t1 t2 => Some (cons fml k)
      end.

    Fixpoint simplify_formulas {Σ} (fmls : List Formula Σ) (k : List Formula Σ) : option (List Formula Σ) :=
      match fmls with
      | nil           => Some k
      | cons fml fmls =>
        option_bind (simplify_formula fml) (simplify_formulas fmls k)
      end.

    Lemma simplify_formula_bool_spec {Σ} (t : Term Σ ty_bool) (k : List Formula Σ) :
      OptionSpec
        (fun fmlsk => forall ι, instpc fmlsk ι <-> inst (formula_bool t) ι /\ instpc k ι)
        (forall ι, ~ inst (formula_bool t) ι)
        (simplify_formula_bool t k).
    Proof.
      dependent elimination t; cbn; try constructor.
      - intros ι. rewrite inst_pathcondition_cons. reflexivity.
      - destruct l; constructor; intuition.
      - intros ι. rewrite inst_pathcondition_cons. reflexivity.
      - intros ι. rewrite inst_pathcondition_cons. reflexivity.
      - intros ι. rewrite inst_pathcondition_cons. reflexivity.
    Qed.

    Lemma simplify_formula_eqb_spec {Σ σ} (t1 t2 : Term Σ σ) (k : List Formula Σ) :
      OptionSpec
        (fun fmlsk => forall ι, instpc fmlsk ι <-> inst (formula_eq t1 t2) ι /\ instpc k ι)
        (forall ι, ~ inst (formula_eq t1 t2) ι)
        (simplify_formula_eqb t1 t2 k).
    Proof.
      unfold simplify_formula_eqb.
      destruct (Term_eqb_spec t1 t2); constructor; intros ι.
      - subst; intuition.
      - now rewrite inst_pathcondition_cons.
    Qed.

    Lemma simplify_formula_eq_spec {Σ σ} (s t : Term Σ σ) (k : List Formula Σ) :
      OptionSpec
        (fun fmlsk : List Formula Σ => forall ι, instpc fmlsk ι <-> inst (formula_eq s t) ι /\ instpc k ι)
        (forall ι, ~ inst (formula_eq s t) ι)
        (simplify_formula_eq s t k).
    Proof.
      induction s; try apply simplify_formula_eqb_spec;
        dependent elimination t; try (cbn; constructor; intros;
          rewrite ?inst_pathcondition_cons; auto; fail).
      - cbn. destruct (Lit_eqb_spec σ1 l l0); constructor; intuition.
      - specialize (IHs t). revert IHs. apply optionspec_monotonic.
        + intros fmls HYP ι. specialize (HYP ι). rewrite HYP. cbn.
          apply and_iff_compat_r. cbn. split; intros Heq.
          * now f_equal.
          * apply noConfusion_inv in Heq. apply Heq.
        + intros HYP ι Heq. apply noConfusion_inv in Heq. apply (HYP ι Heq).
      - specialize (IHs t0). revert IHs. apply optionspec_monotonic.
        + intros fmls HYP ι. specialize (HYP ι). rewrite HYP. cbn.
          apply and_iff_compat_r. cbn. split; intros Heq.
          * now f_equal.
          * apply noConfusion_inv in Heq. apply Heq.
        + intros HYP ι Heq. apply noConfusion_inv in Heq. apply (HYP ι Heq).
      - cbn - [inst_term]. constructor. intros ι.
        rewrite inst_pathcondition_app. apply and_iff_compat_r.
        rewrite inst_formula_eqs_nctx. cbn [inst_term].
        split; intros Heq.
        + f_equal. apply Heq.
        + apply (@f_equal _ _ (@𝑹_unfold R0)) in Heq.
          rewrite ?𝑹_unfold_fold in Heq. apply Heq.
    Qed.

    Lemma simplify_formula_spec {Σ} (fml : Formula Σ) (k : List Formula Σ) :
      OptionSpec
        (fun fmlsk : List Formula Σ => forall ι, instpc fmlsk ι <-> inst fml ι /\ instpc k ι)
        (forall ι, ~ inst fml ι)
        (simplify_formula fml k).
    Proof.
      destruct fml; cbn.
      - apply simplify_formula_bool_spec.
      - constructor. intros ι. now rewrite inst_pathcondition_cons.
      - apply simplify_formula_eq_spec.
      - constructor. intros ι. now rewrite inst_pathcondition_cons.
    Qed.

    Lemma simplify_formulas_spec {Σ} (fmls k : List Formula Σ) :
      OptionSpec
        (fun fmlsk : List Formula Σ => forall ι, instpc fmlsk ι <-> instpc fmls ι /\ instpc k ι)
        (forall ι, ~ instpc fmls ι)
        (simplify_formulas fmls k).
    Proof.
      induction fmls as [|fml fmls]; cbn.
      - constructor. intuition. constructor.
      - apply optionspec_bind. revert IHfmls.
        apply optionspec_monotonic.
        + intros fmlsk Hfmls.
          generalize (simplify_formula_spec fml fmlsk).
          apply optionspec_monotonic.
          * intros ? Hfml ι. specialize (Hfmls ι). specialize (Hfml ι).
            rewrite inst_pathcondition_cons. intuition.
          * intros Hfml ι. specialize (Hfml ι).
            rewrite inst_pathcondition_cons. intuition.
        + intros Hfmls ι. specialize (Hfmls ι).
          rewrite inst_pathcondition_cons. intuition.
    Qed.

    Definition occurs_check_lt {Σ x} (xIn : x ∈ Σ) {σ} (t : Term Σ σ) : option (Term (Σ - x) σ) :=
      match t with
      | @term_var _ y σ yIn =>
        if Nat.ltb (inctx_at xIn) (inctx_at yIn) then occurs_check xIn t else None
      | _ => occurs_check xIn t
      end.

    Lemma occurs_check_lt_sound {Σ x} (xIn : x ∈ Σ) {σ} (t : Term Σ σ) (t' : Term (Σ - x) σ) :
      occurs_check_lt xIn t = Some t' -> t = subst t' (sub_shift xIn).
    Proof.
      unfold occurs_check_lt. intros Heq.
      refine (occurs_check_sound xIn t (t' := t') _).
      destruct t; auto.
      destruct (inctx_at xIn <? inctx_at ςInΣ); auto.
      discriminate.
    Qed.

    Equations(noeqns) try_unify_bool {w : World} (t : Term w ty_bool) :
      option { w' & MultiSub w w' } :=
      try_unify_bool (@term_var _ x σ xIn) :=
        Some (existT _ (multisub_cons x (term_lit ty_bool true) multisub_id));
      try_unify_bool (term_not (@term_var _ x σ xIn)) :=
        Some (existT _ (multisub_cons x (term_lit ty_bool false) multisub_id));
      try_unify_bool _ :=
        None.

    Definition try_unify_eq {w : World} {σ} (t1 t2 : Term w σ) :
      option { w' & MultiSub w w' } :=
      match t1 with
      | @term_var _ ς σ ςInΣ =>
        fun t2 : Term w σ =>
          match occurs_check_lt ςInΣ t2 with
          | Some t => Some (existT _ (multisub_cons ς t multisub_id))
          | None => None
          end
      | _ => fun _ => None
      end t2.

    Definition try_unify_formula {w : World} (fml : Formula w) :
      option { w' & MultiSub w w' } :=
      match fml with
      | formula_bool t => try_unify_bool t
      | formula_eq t1 t2 =>
        match try_unify_eq t1 t2 with
        | Some r => Some r
        | None => try_unify_eq t2 t1
        end
      | _ => None
      end.

    Lemma try_unify_bool_spec {w : World} (t : Term w ty_bool) :
      OptionSpec (fun '(existT w' ν) => forall ι, inst (T := STerm ty_bool) t ι = true <-> inst_multisub ν ι) True (try_unify_bool t).
    Proof.
      dependent elimination t; cbn; try constructor; auto.
      intros ι. cbn. intuition.
      dependent elimination e0; cbn; try constructor; auto.
      intros ι. cbn. destruct (ι ‼ ς)%exp; intuition.
    Qed.

    Lemma try_unify_eq_spec {w : World} {σ} (t1 t2 : Term w σ) :
      OptionSpec (fun '(existT w' ν) => forall ι, inst t1 ι = inst t2 ι <-> inst_multisub ν ι) True (try_unify_eq t1 t2).
    Proof.
      unfold try_unify_eq. destruct t1; cbn; try (constructor; auto; fail).
      destruct (occurs_check_lt ςInΣ t2) eqn:Heq; constructor; auto.
      apply occurs_check_lt_sound in Heq. subst.
      intros ι. rewrite inst_subst, inst_sub_shift.
      cbn. intuition.
    Qed.

    Lemma try_unify_formula_spec {w : World} (fml : Formula w) :
      OptionSpec (fun '(existT w' ν) => forall ι, (inst fml ι : Prop) <-> inst_multisub ν ι) True (try_unify_formula fml).
    Proof.
      unfold try_unify_formula; destruct fml; cbn; try (constructor; auto; fail).
      - apply try_unify_bool_spec.
      - destruct (try_unify_eq_spec t1 t2) as [[w' ν] HYP|_]. constructor. auto.
        destruct (try_unify_eq_spec t2 t1) as [[w' ν] HYP|_]. constructor.
        intros ι. specialize (HYP ι). intuition.
        now constructor.
    Qed.

    Definition unify_formula {w0 : World} (fml : Formula w0) :
      { w1 & MultiSub w0 w1 * List Formula w1 }%type :=
      match try_unify_formula fml with
      | Some (existT w1 ν01) => existT w1 (ν01 , nil)
      | None => existT w0 (multisub_id , cons fml nil)
      end.

    Lemma unify_formula_spec {w0 : World} (fml : Formula w0) :
      match unify_formula fml with
      | existT w1 (ν01 , fmls) =>
        (forall ι0 : SymInstance w0,
            inst (A := Prop) fml ι0 ->
            inst_multisub ν01 ι0 /\
            instpc fmls (inst (sub_multishift ν01) ι0)) /\
        (forall ι1 : SymInstance w1,
            instpc fmls ι1 ->
            inst (A := Prop) fml (inst (wsub (wmultisub_sup ν01)) ι1))
      end.
    Proof.
      unfold unify_formula.
      destruct (try_unify_formula_spec fml).
      - destruct a as [w1 ν01]. split.
        + intros ι0 Hfml. specialize (H ι0). intuition. constructor.
        + intros ι1 []. apply H. apply inst_multisub_inst_sub_multi.
      - split; intros ?; rewrite inst_pathcondition_cons;
          cbn; rewrite inst_sub_id; intuition.
    Qed.

    Fixpoint unify_formulas {w0 : World} (fmls : List Formula w0) :
      { w1 & MultiSub w0 w1 * List Formula w1 }%type.
    Proof.
      destruct fmls as [|fml fmls].
      - exists w0. split. apply multisub_id. apply nil.
      - destruct (unify_formulas w0 fmls) as (w1 & ν01 & fmls1).
        clear unify_formulas fmls.
        destruct (unify_formula (subst fml (wmultisub_sup ν01))) as (w2 & ν12 & fmls2).
        exists w2. split. apply (multisub_app ν01 ν12).
        refine (app fmls2 (subst fmls1 (wmultisub_sup ν12))).
    Defined.

    Lemma unify_formulas_spec {w0 : World} (fmls0 : List Formula w0) :
      match unify_formulas fmls0 with
      | existT w1 (ν01 , fmls1) =>
        (forall ι0 : SymInstance w0,
            instpc fmls0 ι0 ->
            inst_multisub ν01 ι0 /\
            instpc fmls1 (inst (sub_multishift ν01) ι0)) /\
        (forall ι1 : SymInstance w1,
            instpc fmls1 ι1 ->
            instpc fmls0 (inst (wsub (wmultisub_sup ν01)) ι1))
      end.
    Proof.
      induction fmls0 as [|fml0 fmls0]; cbn.
      - split; intros ι0; rewrite inst_sub_id; intuition.
      - destruct (unify_formulas fmls0) as (w1 & ν01 & fmls1).
        pose proof (unify_formula_spec (subst fml0 (wmultisub_sup ν01))) as IHfml.
        destruct (unify_formula (subst fml0 (wmultisub_sup ν01))) as (w2 & ν12 & fmls2).
        destruct IHfmls0 as [IHfmls01 IHfmls10].
        destruct IHfml as [IHfml12 IHfml21].
        split.
        + intros ι0. rewrite inst_pathcondition_cons. intros [Hfml Hfmls].
          specialize (IHfmls01 ι0 Hfmls). destruct IHfmls01 as [Hν01 Hfmls1].
          specialize (IHfml12 (inst (sub_multishift ν01) ι0)).
          rewrite inst_subst, inst_multi in IHfml12; auto.
          specialize (IHfml12 Hfml). destruct IHfml12 as [Hν12 Hfmls2].
          rewrite inst_pathcondition_app, inst_subst, inst_multisub_app.
          split; auto. rewrite sub_multishift_app, inst_subst. split; auto.
          revert Hfmls1. remember (inst (sub_multishift ν01) ι0) as ι1.
          rewrite <- ?inst_subst, <- subst_sub_comp, ?inst_subst.
          rewrite inst_multi; auto.
        + intros ι2. rewrite ?inst_pathcondition_app, ?inst_subst.
          intros [Hfmls2 Hfmls1].
          specialize (IHfml21 ι2 Hfmls2). rewrite inst_subst in IHfml21.
          specialize (IHfmls10 (inst (wsub (wmultisub_sup ν12)) ι2) Hfmls1).
          rewrite wmultisub_sup_app, inst_subst.
          rewrite inst_pathcondition_cons. split; auto.
    Qed.

    Open Scope lazy_bool_scope.
    Equations(noind) formula_eqb {Σ} (f1 f2 : Formula Σ) : bool :=
      formula_eqb (formula_bool t1) (formula_bool t2) := Term_eqb t1 t2;
      formula_eqb (@formula_eq _ σ t11 t12) (@formula_eq _ τ t21 t22) with eq_dec σ τ => {
        formula_eqb (@formula_eq _ σ t11 t12) (@formula_eq _ ?(σ) t21 t22) (left eq_refl) :=
          Term_eqb t11 t21 &&& Term_eqb t12 t22;
       formula_eqb (@formula_eq _ σ t11 t12) (@formula_eq _ τ t21 t22) (right _) := false
      };
      formula_eqb (@formula_neq _ σ t11 t12) (@formula_neq _ τ t21 t22) with eq_dec σ τ => {
        formula_eqb (@formula_neq _ σ t11 t12) (@formula_neq _ ?(σ) t21 t22) (left eq_refl) :=
          Term_eqb t11 t21 &&& Term_eqb t12 t22;
        formula_eqb (@formula_neq _ σ t11 t12) (@formula_neq _ τ t21 t22) (right _) := false
      };
      formula_eqb _ _ := false.

    Lemma formula_eqb_spec {Σ} (f1 f2 : Formula Σ) :
      BoolSpec (f1 = f2) True (formula_eqb f1 f2).
    Proof.
      induction f1; dependent elimination f2;
        simp formula_eqb;
        try (constructor; auto; fail).
      - destruct (Term_eqb_spec t t0); constructor; intuition.
      - destruct (eq_dec σ σ0); cbn.
        + destruct e.
          repeat
            match goal with
            | |- context[Term_eqb ?t1 ?t2] =>
              destruct (Term_eqb_spec t1 t2); cbn;
                try (constructor; intuition; fail)
            end.
        + constructor; auto.
      - destruct (eq_dec σ σ1); cbn.
        + destruct e.
          repeat
            match goal with
            | |- context[Term_eqb ?t1 ?t2] =>
              destruct (Term_eqb_spec t1 t2); cbn;
                try (constructor; intuition; fail)
            end.
        + constructor; auto.
    Qed.

    Fixpoint assumption_formula {Σ} (pc : PathCondition Σ) (fml : Formula Σ) (k : List Formula Σ) {struct pc} : List Formula Σ :=
      match pc with
      | nil       => cons fml k
      | cons f pc => if formula_eqb f fml
                     then k
                     else assumption_formula pc fml k
      end.

    Fixpoint assumption_formulas {Σ} (pc : PathCondition Σ) (fmls : List Formula Σ) (k : List Formula Σ) {struct fmls} : List Formula Σ :=
      match fmls with
      | nil           => k
      | cons fml fmls => assumption_formula pc fml (assumption_formulas pc fmls k)
      end.

    Lemma assumption_formula_spec {Σ} (pc : PathCondition Σ) (fml : Formula Σ) (k : List Formula Σ) (ι : SymInstance Σ) :
      instpc pc ι -> inst (A := Prop) fml ι /\ instpc k ι <-> instpc (assumption_formula pc fml k) ι.
    Proof.
      induction pc as [|f pc]; cbn.
      - now rewrite inst_pathcondition_cons.
      - rewrite inst_pathcondition_cons.
        intros [Hf Hpc]. specialize (IHpc Hpc).
        destruct (formula_eqb_spec f fml);
          subst; intuition.
    Qed.

    Lemma assumption_formulas_spec {Σ} (pc : PathCondition Σ) (fmls : List Formula Σ) (k : List Formula Σ) (ι : SymInstance Σ) :
      instpc pc ι -> instpc fmls ι /\ instpc k ι <-> instpc (assumption_formulas pc fmls k) ι.
    Proof.
      intros Hpc. induction fmls as [|fml fmls]; cbn.
      - intuition. constructor.
      - rewrite inst_pathcondition_cons.
        pose proof (assumption_formula_spec pc fml (assumption_formulas pc fmls k) ι Hpc).
        intuition.
    Qed.

    Definition round {w0 : World} (fmls0 : List Formula w0) :
      option { w1 & MultiSub w0 w1 * List Formula w1 }%type.
    Proof.
      destruct (simplify_formulas fmls0 nil) as [fmls01|].
      - apply Some.
        apply unify_formulas.
        apply (assumption_formulas (wco w0) fmls01 nil).
      - apply None.
    Defined.

    Lemma round_spec {w0 : World} (fmls0 : List Formula w0) :
      OptionSpec
        (fun '(existT w1 (ζ, fmls1)) =>
           forall ι0,
             instpc (wco w0) ι0 ->
             (instpc fmls0 ι0 -> inst_multisub ζ ι0) /\
             (forall ι1,
                 instpc (wco w1) ι1 ->
                 ι0 = inst (wsub (wmultisub_sup ζ)) ι1 ->
                 instpc fmls0 ι0 <-> inst fmls1 ι1))
        (forall ι, instpc (wco w0) ι -> ~ instpc fmls0 ι)
        (round fmls0).
    Proof.
      unfold round.
      destruct (simplify_formulas_spec fmls0 nil) as [fmls0' Hequiv|].
      - constructor.
        pose proof (unify_formulas_spec (assumption_formulas (wco w0) fmls0' [])) as Hunify.
        destruct (unify_formulas (assumption_formulas (wco w0) fmls0' [])) as (w1 & ν01 & fmls1).
        intros ι0 Hpc0. specialize (Hequiv ι0).
        pose proof (assumption_formulas_spec (wco w0) fmls0' [] ι0 Hpc0) as Hassumption.
        destruct Hassumption as [Hassumption01 Hassumption10].
        destruct Hunify as [Hunify01 Hunify10]. specialize (Hunify01 ι0).
        split.
        + intros Hfmls0. apply Hunify01. apply Hassumption01.
          split. apply Hequiv. split; auto. constructor.
          constructor.
        + intros ι1 Heqι. specialize (Hunify10 ι1).
          split.
          * intros Hfmls0. destruct Hequiv as [_ Hequiv].
            inster Hequiv by split; auto; constructor.
            inster Hassumption01 by split; auto; constructor.
            inster Hunify01 by auto. destruct Hunify01 as [Hν01 Hfmls1].
            revert Hfmls1. subst. now rewrite inst_multishift_multisub.
          * intros Hfmls1. inster Hunify10 by subst; auto.
            apply Hequiv. apply Hassumption10. subst; auto.
      - constructor. intuition.
    Qed.

    Definition solver {w0 : World} (fmls0 : List Formula w0) :
      option { w1 & MultiSub w0 w1 * List Formula w1 }%type :=
      option_bind
        (fun '(existT w1 (ν01 , fmls1)) =>
           option_map
             (fun '(existT w2 (ν12 , fmls2)) =>
                existT w2 (multisub_app ν01 ν12 , fmls2))
             (round fmls1)) (round fmls0).

    Lemma solver_spec {w0 : World} (fmls0 : List Formula w0) :
      OptionSpec
        (fun '(existT w1 (ζ, fmls1)) =>
           forall ι0,
             instpc (wco w0) ι0 ->
             (instpc fmls0 ι0 -> inst_multisub ζ ι0) /\
             (forall ι1,
                 instpc (wco w1) ι1 ->
                 ι0 = inst (wsub (wmultisub_sup ζ)) ι1 ->
                 instpc fmls0 ι0 <-> inst fmls1 ι1))
        (forall ι, instpc (wco w0) ι -> ~ instpc fmls0 ι)
        (solver fmls0).
    Proof.
      unfold solver.
      apply optionspec_bind.
      generalize (round_spec fmls0).
      apply optionspec_monotonic; auto.
      intros (w1 & ν01 & fmls1) H1.
      apply optionspec_map.
      generalize (round_spec fmls1).
      apply optionspec_monotonic; auto.
      - intros (w2 & ν12 & fmls2) H2. intros ι0 Hpc0.
        specialize (H1 ι0 Hpc0). destruct H1 as [H01 H10].
        rewrite inst_multisub_app. split.
        + intros Hfmls0. split; auto.
          remember (inst (sub_multishift ν01) ι0) as ι1.
          assert (instpc (wco w1) ι1) as Hpc1 by
            (subst; apply multishift_entails; auto).
          apply H2; auto. apply H10; auto.
          subst; rewrite inst_multi; auto.
        + intros ι2 Hpc2 Hι0. rewrite wmultisub_sup_app, inst_subst in Hι0.
          remember (inst (wsub (wmultisub_sup ν12)) ι2) as ι1.
          assert (instpc (wco w1) ι1) as Hpc1 by
            (revert Hpc2; subst; rewrite <- inst_subst; apply went).
          rewrite H10; eauto. apply H2; auto.
      - intros Hfmls1 ι0 Hpc0 Hfmls0. specialize (H1 ι0 Hpc0).
        destruct H1 as [H01 H10]. inster H01 by auto.
        pose (inst (sub_multishift ν01) ι0) as ι1.
        assert (instpc (wco w1) ι1) as Hpc1 by
          (subst; apply multishift_entails; auto).
        apply (Hfmls1 ι1 Hpc1). revert Hfmls0.
        apply H10; auto. subst ι1.
        now rewrite inst_multi.
    Qed.

  End Solver.

  Module SPath.

    Inductive EMessage (Σ : LCtx) : Type :=
    | EMsgHere (msg : Message Σ)
    | EMsgThere {b} (msg : EMessage (Σ ▻ b)).

    Fixpoint shift_emsg {Σ b} (bIn : b ∈ Σ) (emsg : EMessage (Σ - b)) : EMessage Σ :=
      match emsg with
      | EMsgHere msg   => EMsgHere (subst msg (sub_shift bIn))
      | EMsgThere emsg => EMsgThere (shift_emsg (inctx_succ bIn) emsg)
      end.

    Inductive SPath (Σ : LCtx) : Type :=
    | angelic_binary (o1 o2 : SPath Σ)
    | demonic_binary (o1 o2 : SPath Σ)
    | error (msg : EMessage Σ)
    | block
    | assertk (fml : Formula Σ) (msg : Message Σ) (k : SPath Σ)
    | assumek (fml : Formula Σ) (k : SPath Σ)
    (* Don't use these two directly. Instead, use the HOAS versions 'angelic' *)
    (* and 'demonic' that will freshen names. *)
    | angelicv b (k : SPath (Σ ▻ b))
    | demonicv b (k : SPath (Σ ▻ b))
    | assert_vareq
        x σ (xIn : x::σ ∈ Σ)
        (t : Term (Σ - (x::σ)) σ)
        (msg : Message (Σ - (x::σ)))
        (k : SPath (Σ - (x::σ)))
    | assume_vareq
        x σ (xIn : (x,σ) ∈ Σ)
        (t : Term (Σ - (x::σ)) σ)
        (k : SPath (Σ - (x::σ)))
    | debug
        {BT B} {subB : Subst BT}
        {instB : Inst BT B}
        {occB: OccursCheck BT}
        (b : BT Σ) (k : SPath Σ).

    Global Arguments error {_} _.
    Global Arguments block {_}.
    Global Arguments assertk {_} fml msg k.
    Global Arguments assumek {_} fml k.
    Global Arguments angelicv {_} _ _.
    Global Arguments demonicv {_} _ _.
    Global Arguments assert_vareq {_} x {_ _} t msg k.
    Global Arguments assume_vareq {_} x {_ _} t k.

    Definition angelic_close0 {Σ0 : LCtx} :
      forall Σ, SPath (Σ0 ▻▻ Σ) -> SPath Σ0 :=
      fix close Σ :=
        match Σ with
        | ε     => fun p => p
        | Σ ▻ b => fun p => close Σ (angelicv b p)
        end.

    Definition demonic_close :
      forall Σ, SPath Σ -> SPath ε :=
      fix close Σ :=
        match Σ with
        | ctx_nil      => fun k => k
        | ctx_snoc Σ b => fun k => close Σ (@demonicv Σ b k)
        end.

    (* Global Instance persistent_spath : Persistent SPath := *)
    (*   (* ⊢ SPath -> □SPath := *) *)
    (*    fix pers (w0 : World) (p : SPath w0) {w1 : World} ω01 {struct p} : SPath w1 := *)
    (*      match p with *)
    (*      | angelic_binary p1 p2 => angelic_binary (pers w0 p1 ω01) (pers w0 p2 ω01) *)
    (*      | demonic_binary p1 p2 => demonic_binary (pers w0 p1 ω01) (pers w0 p2 ω01) *)
    (*      | error msg            => error (subst msg (wsub ω01)) *)
    (*      | block                => block *)
    (*      | assertk fml msg p0   => *)
    (*          assertk (subst fml (wsub ω01)) (subst msg (wsub ω01)) *)
    (*            (pers (wformula w0 fml) p0 (wacc_formula ω01 fml)) *)
    (*      | assumek fml p        => *)
    (*          assumek (subst fml (wsub ω01)) *)
    (*            (pers (wformula w0 fml) p (wacc_formula ω01 fml)) *)
    (*      | angelicv b p0        => angelicv b (pers (wsnoc w0 b) p0 (wacc_snoc ω01 b)) *)
    (*      | demonicv b p0        => demonicv b (pers (wsnoc w0 b) p0 (wacc_snoc ω01 b)) *)
    (*      | assert_vareq x t msg p => *)
    (*        let ζ := subst (sub_shift _) (wsub ω01) in *)
    (*        assertk *)
    (*          (formula_eq (env_lookup (wsub ω01) _) (subst t ζ)) *)
    (*          (subst msg ζ) *)
    (*          (pers (wsubst w0 x t) p *)
    (*             (MkAcc (MkWorld (subst (wco w0) (sub_single _ t))) *)
    (*                (MkWorld *)
    (*                   (cons (formula_eq (env_lookup (wsub ω01) _) (subst t ζ)) *)
    (*                      (wco w1))) ζ)) *)
    (*      | assume_vareq x t p => *)
    (*        let ζ := subst (sub_shift _) (wsub ω01) in *)
    (*        assumek *)
    (*          (formula_eq (env_lookup (wsub ω01) _) (subst t ζ)) *)
    (*          (pers (wsubst w0 x t) p *)
    (*             (MkAcc (MkWorld (subst (wco w0) (sub_single _ t))) *)
    (*                (MkWorld *)
    (*                   (cons (formula_eq (env_lookup (wsub ω01) _) (subst t ζ)) *)
    (*                      (wco w1))) ζ)) *)
    (*      | debug d p => debug (subst d (wsub ω01)) (pers w0 p ω01) *)
    (*      end. *)

    Fixpoint assume_formulas_without_solver' {Σ}
      (fmls : List Formula Σ) (p : SPath Σ) : SPath Σ :=
      match fmls with
      | nil           => p
      | cons fml fmls => assume_formulas_without_solver' fmls (assumek fml p)
      end.

    Fixpoint assert_formulas_without_solver' {Σ}
      (msg : Message Σ) (fmls : List Formula Σ) (p : SPath Σ) : SPath Σ :=
      match fmls with
      | nil => p
      | cons fml fmls =>
        assert_formulas_without_solver' msg fmls (assertk fml msg p)
      end.

    (* These versions just add the world indexing. They simply enforces
       that p should have been computed in the world with fmls added. *)
    Definition assume_formulas_without_solver {w : World}
      (fmls : List Formula w) (p : SPath (wformulas w fmls)) : SPath w :=
      assume_formulas_without_solver' fmls p.
    Global Arguments assume_formulas_without_solver {_} fmls p.

    Definition assert_formulas_without_solver {w : World} (msg : Message w)
      (fmls : List Formula w) (p : SPath (wformulas w fmls)) : SPath w :=
      assert_formulas_without_solver' msg fmls p.
    Global Arguments assert_formulas_without_solver {_} msg fmls p.

    Fixpoint assume_multisub {w1 w2} (ν : MultiSub w1 w2) :
      SPath w2 -> SPath w1.
    Proof.
      destruct ν; intros o; cbn in o.
      - exact o.
      - apply (@assume_vareq w1 x σ xIn t).
        eapply (assume_multisub _ _ ν o).
    Defined.

    Fixpoint assert_multisub {w1 w2} (msg : Message (wctx w1)) (ζ : MultiSub w1 w2) :
      (Message w2 -> SPath w2) -> SPath w1.
    Proof.
      destruct ζ; intros o; cbn in o.
      - apply o. apply msg.
      - apply (@assert_vareq w1 x σ xIn t).
        apply (subst msg (sub_single xIn t)).
        refine (assert_multisub (wsubst w1 x t) _ (subst msg (sub_single xIn t)) ζ o).
    Defined.

    Fixpoint safe {Σ} (p : SPath Σ) (ι : SymInstance Σ) : Prop :=
      (* ⊢ SPath -> SymInstance -> PROP := *)
        match p with
        | angelic_binary o1 o2 => safe o1 ι \/ safe o2 ι
        | demonic_binary o1 o2 => safe o1 ι /\ safe o2 ι
        | error msg => False
        | block => True
        | assertk fml msg o =>
          Obligation msg fml ι /\ safe o ι
        | assumek fml o => (inst fml ι : Prop) -> safe o ι
        | angelicv b k => exists v, safe k (env_snoc ι b v)
        | demonicv b k => forall v, safe k (env_snoc ι b v)
        | @assert_vareq _ x σ xIn t msg k =>
          (let ζ := sub_shift xIn in
          Obligation (subst msg ζ) (formula_eq (term_var x) (subst t ζ))) ι /\
          (let ι' := env_remove (x,σ) ι xIn in
          safe k ι')
        | @assume_vareq _ x σ xIn t k =>
          let ι' := env_remove (x,σ) ι xIn in
          env_lookup ι xIn = inst t ι' ->
          safe k ι'
        | debug d k => Debug (inst d ι) (safe k ι)
        end%type.
    Global Arguments safe {Σ} p ι.

    (* We use a world indexed version of safe in the soundness proofs, just to make
       Coq's unifier happy. *)
    Fixpoint wsafe {w : World} (p : SPath w) (ι : SymInstance w) : Prop :=
      (* ⊢ SPath -> SymInstance -> PROP := *)
        match p with
        | angelic_binary o1 o2 => wsafe o1 ι \/ wsafe o2 ι
        | demonic_binary o1 o2 => wsafe o1 ι /\ wsafe o2 ι
        | error msg => False
        | block => True
        | assertk fml msg o =>
          Obligation msg fml ι /\ @wsafe (wformula w fml) o ι
        | assumek fml o => (inst fml ι : Prop) -> @wsafe (wformula w fml) o ι
        | angelicv b k => exists v, @wsafe (wsnoc w b) k (env_snoc ι b v)
        | demonicv b k => forall v, @wsafe (wsnoc w b) k (env_snoc ι b v)
        | @assert_vareq _ x σ xIn t msg k =>
          (let ζ := sub_shift xIn in
          Obligation (subst msg ζ) (formula_eq (term_var x) (subst t ζ))) ι /\
          (let ι' := env_remove (x,σ) ι xIn in
          @wsafe (wsubst w x t) k ι')
        | @assume_vareq _ x σ xIn t k =>
          let ι' := env_remove (x,σ) ι xIn in
          env_lookup ι xIn = inst t ι' ->
          @wsafe (wsubst w x t) k ι'
        | debug d k => Debug (inst d ι) (wsafe k ι)
        end%type.
    Global Arguments wsafe {w} p ι.

    Lemma obligation_equiv {Σ : LCtx} (msg : Message Σ) (fml : Formula Σ) (ι : SymInstance Σ) :
      Obligation msg fml ι <-> inst fml ι.
    Proof. split. now intros []. now constructor. Qed.

    Lemma debug_equiv {B : Type} {b : B} {P : Prop} :
      @Debug B b P <-> P.
    Proof. split. now intros []. now constructor. Qed.

    Lemma wsafe_safe {w : World} (p : SPath w) (ι : SymInstance w) :
      wsafe p ι <-> safe p ι.
    Proof.
      destruct w as [Σ pc]; cbn in *; revert pc.
      induction p; cbn; intros pc; rewrite ?debug_equiv; auto;
        try (intuition; fail).
      apply base.exist_proper; eauto.
    Qed.

    (* Lemma safe_persist  {w1 w2 : World} (ω12 : w1 ⊒ w2) *)
    (*       (o : SPath w1) (ι2 : SymInstance w2) : *)
    (*   safe (persist (A := SPath) o ω12) ι2 <-> *)
    (*   safe o (inst (T := Sub _) ω12 ι2). *)
    (* Proof. *)
    (*   revert w2 ω12 ι2. *)
    (*   induction o; cbn; intros. *)
    (*   - now rewrite IHo1, IHo2. *)
    (*   - now rewrite IHo1, IHo2. *)
    (*   - split; intros []. *)
    (*   - reflexivity. *)
    (*   - rewrite ?obligation_equiv. *)
    (*     now rewrite IHo, inst_subst. *)
    (*   - now rewrite IHo, inst_subst. *)
    (*   - split; intros [v HYP]; exists v; revert HYP; *)
    (*       rewrite IHo; unfold wacc_snoc, wsnoc; *)
    (*         cbn [wctx wsub]; now rewrite inst_sub_up1. *)
    (*   - split; intros HYP v; specialize (HYP v); revert HYP; *)
    (*       rewrite IHo; unfold wacc_snoc, wsnoc; *)
    (*         cbn [wctx wsub]; now rewrite inst_sub_up1. *)
    (*   - rewrite ?obligation_equiv. *)
    (*     rewrite IHo; unfold wsubst; cbn [wctx wsub]. cbn. *)
    (*     now rewrite ?inst_subst, ?inst_sub_shift, <- inst_lookup. *)
    (*   - rewrite IHo; unfold wsubst; cbn [wctx wsub]. *)
    (*     now rewrite ?inst_subst, ?inst_sub_shift, <- inst_lookup. *)
    (*   - now rewrite ?debug_equiv. *)
    (* Qed. *)

    Lemma safe_assume_formulas_without_solver {w0 : World}
      (fmls : List Formula w0) (p : SPath w0) (ι0 : SymInstance w0) :
      wsafe (assume_formulas_without_solver fmls p) ι0 <->
      (instpc fmls ι0 -> @wsafe (wformulas w0 fmls) p ι0).
    Proof.
      unfold assume_formulas_without_solver. revert p.
      induction fmls; cbn in *; intros p.
      - destruct w0; cbn; split; auto.
        intros HYP. apply HYP. constructor.
      - rewrite IHfmls, inst_pathcondition_cons. cbn.
        intuition.
    Qed.

    Lemma safe_assert_formulas_without_solver {w0 : World}
      (msg : Message w0) (fmls : List Formula w0) (p : SPath w0)
      (ι0 : SymInstance w0) :
      wsafe (assert_formulas_without_solver msg fmls p) ι0 <->
      (instpc fmls ι0 /\ @wsafe (wformulas w0 fmls) p ι0).
    Proof.
      unfold assert_formulas_without_solver. revert p.
      induction fmls; cbn in *; intros p.
      - destruct w0; cbn; split.
        + intros HYP. split; auto. constructor.
        + intros []; auto.
      - rewrite IHfmls, inst_pathcondition_cons; cbn.
        split; intros []; auto.
        + destruct H0. destruct H0. auto.
        + destruct H. split; auto. split; auto.
          constructor. auto.
    Qed.

    Lemma safe_assume_multisub {w0 w1} (ζ : MultiSub w0 w1)
      (o : SPath w1) (ι0 : SymInstance w0) :
      wsafe (assume_multisub ζ o) ι0 <->
      (inst_multisub ζ ι0 -> wsafe o (inst (sub_multishift ζ) ι0)).
    Proof.
      induction ζ; cbn in *.
      - rewrite inst_sub_id. intuition.
      - rewrite IHζ. clear IHζ.
        rewrite <- inst_sub_shift.
        rewrite inst_subst.
        intuition.
    Qed.

    Lemma safe_assert_multisub {w0 w1} msg (ζ : MultiSub w0 w1)
      (o : Message w1 -> SPath w1) (ι0 : SymInstance w0) :
      wsafe (assert_multisub msg ζ o) ι0 <->
      (inst_multisub ζ ι0 /\ wsafe (o (subst msg (wmultisub_sup ζ))) (inst (sub_multishift ζ) ι0)).
    Proof.
      induction ζ.
      - cbn. rewrite inst_sub_id, subst_sub_id. intuition.
      - cbn [wsafe assert_multisub inst_multisub
                  sub_multishift wmultisub_sup wtrans wsub].
        rewrite obligation_equiv.
        rewrite subst_sub_comp. cbn.
        rewrite IHζ. clear IHζ.
        rewrite <- inst_sub_shift.
        rewrite ?inst_subst.
        intuition.
    Qed.

    (* Fixpoint occurs_check_spath {Σ x} (xIn : x ∈ Σ) (p : SPath Σ) : option (SPath (Σ - x)) := *)
    (*   match p with *)
    (*   | angelic_binary o1 o2 => *)
    (*     option_ap (option_map (angelic_binary (Σ := Σ - x)) (occurs_check_spath xIn o1)) (occurs_check_spath xIn o2) *)
    (*   | demonic_binary o1 o2 => *)
    (*     option_ap (option_map (demonic_binary (Σ := Σ - x)) (occurs_check_spath xIn o1)) (occurs_check_spath xIn o2) *)
    (*   | error msg => option_map error (occurs_check xIn msg) *)
    (*   | block => Some block *)
    (*   | assertk P msg o => *)
    (*     option_ap (option_ap (option_map (assertk (Σ := Σ - x)) (occurs_check xIn P)) (occurs_check xIn msg)) (occurs_check_spath xIn o) *)
    (*   | assumek P o => option_ap (option_map (assumek (Σ := Σ - x)) (occurs_check xIn P)) (occurs_check_spath xIn o) *)
    (*   | angelicv b o => option_map (angelicv b) (occurs_check_spath (inctx_succ xIn) o) *)
    (*   | demonicv b o => option_map (demonicv b) (occurs_check_spath (inctx_succ xIn) o) *)
    (*   | @assert_vareq _ y σ yIn t msg o => *)
    (*     match occurs_check_view yIn xIn with *)
    (*     | Same _ => None *)
    (*     | @Diff _ _ _ _ x xIn => *)
    (*       option_ap *)
    (*         (option_ap *)
    (*            (option_map *)
    (*               (fun (t' : Term (Σ - (y :: σ) - x) σ) (msg' : Message (Σ - (y :: σ) - x)) (o' : SPath (Σ - (y :: σ) - x)) => *)
    (*                  let e := swap_remove yIn xIn in *)
    (*                  assert_vareq *)
    (*                    y *)
    (*                    (eq_rect (Σ - (y :: σ) - x) (fun Σ => Term Σ σ) t' (Σ - x - (y :: σ)) e) *)
    (*                    (eq_rect (Σ - (y :: σ) - x) Message msg' (Σ - x - (y :: σ)) e) *)
    (*                    (eq_rect (Σ - (y :: σ) - x) SPath o' (Σ - x - (y :: σ)) e)) *)
    (*               (occurs_check xIn t)) *)
    (*            (occurs_check xIn msg)) *)
    (*         (occurs_check_spath xIn o) *)
    (*     end *)
    (*   | @assume_vareq _ y σ yIn t o => *)
    (*     match occurs_check_view yIn xIn with *)
    (*     | Same _ => Some o *)
    (*     | @Diff _ _ _ _ x xIn => *)
    (*       option_ap *)
    (*         (option_map *)
    (*            (fun (t' : Term (Σ - (y :: σ) - x) σ) (o' : SPath (Σ - (y :: σ) - x)) => *)
    (*               let e := swap_remove yIn xIn in *)
    (*               assume_vareq *)
    (*                 y *)
    (*                 (eq_rect (Σ - (y :: σ) - x) (fun Σ => Term Σ σ) t' (Σ - x - (y :: σ)) e) *)
    (*                 (eq_rect (Σ - (y :: σ) - x) SPath o' (Σ - x - (y :: σ)) e)) *)
    (*            (occurs_check xIn t)) *)
    (*         (occurs_check_spath xIn o) *)
    (*     end *)
    (*   | debug b o => option_ap (option_map (debug (Σ := Σ - x)) (occurs_check xIn b)) (occurs_check_spath xIn o) *)
    (*   end. *)

    Definition angelic_binary_prune {Σ} (p1 p2 : SPath Σ) : SPath Σ :=
      match p1 , p2 with
      | block   , _       => block
      | _       , block   => block
      | error _ , _       => p2
      | _       , error _ => p1
      | _       , _       => angelic_binary p1 p2
      end.

    Definition demonic_binary_prune {Σ} (p1 p2 : SPath Σ) : SPath Σ :=
      match p1 , p2 with
      | block   , _       => p2
      | _       , block   => p1
      | error s , _       => error s
      | _       , error s => error s
      | _       , _       => demonic_binary p1 p2
      end.

    Definition assertk_prune {Σ} (fml : Formula Σ) (msg : Message Σ) (p : SPath Σ) : SPath Σ :=
      match p with
      | error s => @error Σ s
      | _       => assertk fml msg p
      end.
    Global Arguments assertk_prune {Σ} fml msg p.

    Definition assumek_prune {Σ} (fml : Formula Σ) (p : SPath Σ) : SPath Σ :=
      match p with
      | block => block
      | _     => assumek fml p
      end.
    Global Arguments assumek_prune {Σ} fml p.

    Definition angelicv_prune {Σ} b (p : SPath (Σ ▻ b)) : SPath Σ :=
      match p with
      | error msg => error (EMsgThere msg)
      | _         => angelicv b p
      end.

    Definition demonicv_prune {Σ} b (p : SPath (Σ ▻ b)) : SPath Σ :=
      (* match @occurs_check_spath AT _ (Σ ▻ b) b inctx_zero o with *)
      (* | Some o => o *)
      (* | None   => demonicv b o *)
      (* end. *)
      match p with
      | block => block
      | _     => demonicv b p
      end.

    Definition assume_vareq_prune {Σ} {x σ} {xIn : x::σ ∈ Σ}
      (t : Term (Σ - (x::σ)) σ) (k : SPath (Σ - (x::σ))) : SPath Σ :=
      match k with
      | block => block
      | _     => assume_vareq x t k
      end.
    Global Arguments assume_vareq_prune {Σ} x {σ xIn} t k.

    Definition assert_vareq_prune {Σ} {x σ} {xIn : x::σ ∈ Σ}
      (t : Term (Σ - (x::σ)) σ) (msg : Message (Σ - (x::σ))) (k : SPath (Σ - (x::σ))) : SPath Σ :=
      match k with
      | error emsg => error (shift_emsg xIn emsg)
      | _          => assert_vareq x t msg k
      end.
    Global Arguments assert_vareq_prune {Σ} x {σ xIn} t msg k.

    Fixpoint prune {Σ} (p : SPath Σ) : SPath Σ :=
      match p with
      | error msg => error msg
      | block => block
      | angelic_binary o1 o2 =>
        angelic_binary_prune (prune o1) (prune o2)
      | demonic_binary o1 o2 =>
        demonic_binary_prune (prune o1) (prune o2)
      | assertk fml msg o =>
        assertk_prune fml msg (prune o)
      | assumek fml o =>
        assumek_prune fml (prune o)
      | angelicv b o =>
        angelicv_prune (prune o)
      | demonicv b o =>
        demonicv_prune (prune o)
      | assert_vareq x t msg k =>
        assert_vareq_prune x t msg (prune k)
      | assume_vareq x t k =>
        assume_vareq_prune x t (prune k)
      | debug d k =>
        debug d (prune k)
      end.

    Lemma prune_angelic_binary_sound {Σ} (p1 p2 : SPath Σ) (ι : SymInstance Σ) :
      safe (angelic_binary_prune p1 p2) ι <-> safe (angelic_binary p1 p2) ι.
    Proof.
      destruct p1; cbn; auto.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - intuition.
      - destruct p2; cbn; auto;
          rewrite ?obligation_equiv; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto;
          rewrite ?obligation_equiv; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
    Qed.

    Lemma prune_demonic_binary_sound {Σ} (p1 p2 : SPath Σ) (ι : SymInstance Σ) :
      safe (demonic_binary_prune p1 p2) ι <-> safe (demonic_binary p1 p2) ι.
    Proof.
      destruct p1; cbn; auto.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - intuition.
      - destruct p2; cbn; auto;
          rewrite ?obligation_equiv; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto;
          rewrite ?obligation_equiv; intuition.
      - destruct p2; cbn; auto; intuition.
      - destruct p2; cbn; auto; intuition.
    Qed.

    Lemma prune_assertk_sound {Σ} fml msg (p : SPath Σ) (ι : SymInstance Σ) :
      safe (assertk_prune fml msg p) ι <-> safe (assertk fml msg p) ι.
    Proof. destruct p; cbn; rewrite ?obligation_equiv; auto; intuition. Qed.

    Lemma prune_assumek_sound {Σ} fml (p : SPath Σ) (ι : SymInstance Σ) :
      safe (assumek_prune fml p) ι <-> safe (assumek fml p) ι.
    Proof. destruct p; cbn; auto; intuition. Qed.

    Lemma prune_angelicv_sound {Σ b} (p : SPath (Σ ▻ b)) (ι : SymInstance Σ) :
      safe (angelicv_prune p) ι <-> safe (angelicv b p) ι.
    Proof. destruct p; cbn; auto; firstorder. Qed.

    Lemma prune_demonicv_sound {Σ b} (p : SPath (Σ ▻ b)) (ι : SymInstance Σ) :
      safe (demonicv_prune p) ι <-> safe (demonicv b p) ι.
    Proof. destruct p; cbn; auto; intuition. Qed.

    Lemma prune_assert_vareq_sound {Σ x σ} {xIn : x::σ ∈ Σ}
      (t : Term (Σ - (x::σ)) σ) (msg : Message (Σ - (x::σ))) (p : SPath (Σ - (x::σ))) (ι : SymInstance Σ) :
      safe (assert_vareq_prune x t msg p) ι <-> safe (assert_vareq x t msg p) ι.
    Proof. destruct p; cbn; auto; intuition. Qed.

    Lemma prune_assume_vareq_sound {Σ x σ} {xIn : x::σ ∈ Σ}
      (t : Term (Σ - (x::σ)) σ) (p : SPath (Σ - (x::σ))) (ι : SymInstance Σ) :
      safe (assume_vareq_prune x t p) ι <-> safe (assume_vareq x t p) ι.
    Proof. destruct p; cbn; auto; intuition. Qed.

    Lemma prune_sound {Σ} (p : SPath Σ) (ι : SymInstance Σ) :
      safe (prune p) ι <-> safe p ι.
    Proof.
      induction p; cbn [prune safe].
      - rewrite prune_angelic_binary_sound; cbn.
        now rewrite IHp1, IHp2.
      - rewrite prune_demonic_binary_sound; cbn.
        now rewrite IHp1, IHp2.
      - auto.
      - auto.
      - rewrite prune_assertk_sound; cbn.
        now rewrite IHp.
      - rewrite prune_assumek_sound; cbn.
        now rewrite IHp.
      - rewrite prune_angelicv_sound; cbn.
        apply base.exist_proper; intros.
        now rewrite IHp.
      - rewrite prune_demonicv_sound; cbn.
        apply base.forall_proper; intros.
        now rewrite IHp.
      - rewrite prune_assert_vareq_sound; cbn.
        now rewrite IHp.
      - rewrite prune_assume_vareq_sound; cbn.
        now rewrite IHp.
      - now rewrite ?debug_equiv.
    Qed.

    Lemma angelic_close0_sound {Σ0 Σ} (p : SPath (Σ0 ▻▻ Σ)) (ι0 : SymInstance Σ0) :
      safe (angelic_close0 Σ p) ι0 <-> exists (ι : SymInstance Σ), safe p (env_cat ι0 ι).
    Proof.
      induction Σ; cbn.
      - split.
        + intros s.
          now exists env_nil.
        + intros [ι sp].
          destruct (nilView ι).
          now cbn in *.
      - rewrite (IHΣ (angelicv b p)).
        split.
        + intros (ι & v & sp).
          now exists (env_snoc ι b v).
        + intros (ι & sp).
          destruct (snocView ι) as (ι & v).
          now exists ι, v.
    Qed.

    Definition ok {Σ} (p : SPath Σ) : bool :=
      match prune p with
      | block => true
      | _     => false
      end.

    Lemma ok_sound {Σ} (p : SPath Σ) (ι : SymInstance Σ) :
      is_true (ok p) -> safe p ι.
    Proof.
      rewrite <- prune_sound. unfold ok.
      generalize (prune p) as q. clear. intros q.
      destruct q; try discriminate; cbn; auto.
    Qed.

    Module Experimental.

      Fixpoint assert_msgs_formulas {Σ} (mfs : List (Pair Message Formula) Σ) (p : SPath Σ) : SPath Σ :=
        match mfs with
        | nil => p
        | cons (msg,fml) mfs =>
          assert_msgs_formulas mfs (assertk fml msg p)
        end.

      Lemma assert_msgs_formulas_sound {Σ} {mfs : List (Pair Message Formula) Σ} {p : SPath Σ} {ι : SymInstance Σ} :
        (safe (assert_msgs_formulas mfs p) ι <-> instpc (map snd mfs) ι /\ safe p ι).
      Proof.
        revert p.
        induction mfs; intros p; cbn.
        - now unfold inst_pathcondition.
        - rewrite inst_pathcondition_cons.
          destruct a; cbn.
          rewrite IHmfs.
          cbn.
          now rewrite obligation_equiv.
      Qed.

      Arguments InCtx_rect [_ _].
      Lemma ctx_remove_inctx_right {B : Set} {Γ Δ : Ctx B} {b : B} (bIn : InCtx b Δ) :
        @ctx_remove B (@ctx_cat B Γ Δ) b (@inctx_cat_right B b Γ Δ bIn) =
        @ctx_cat B Γ (@ctx_remove B Δ b bIn).
      Proof.
        induction bIn using InCtx_rect; cbn.
        - reflexivity.
        - f_equal. auto.
      Defined.

      Fixpoint solve_evars {Σ} Σe (p : SPath (Σ ▻▻ Σe)) (mfs : List (Pair Message Formula) (Σ ▻▻ Σe)) {struct p} : SPath Σ :=
        match p with
        | angelic_binary p1 p2 =>
          angelic_binary
            (solve_evars Σe p1 mfs)
            (solve_evars Σe p2 mfs)
        | demonic_binary p1 p2 =>
          angelic_close0 Σe
            (assert_msgs_formulas mfs
               (demonic_binary (solve_evars ε p1 []) (solve_evars ε p2 [])))
        | error msg =>
          angelic_close0 Σe (assert_msgs_formulas mfs (error msg))
        | block =>
          angelic_close0 Σe (assert_msgs_formulas mfs block)
        | assertk fml msg p0 =>
          solve_evars Σe p0 (cons (msg,fml) mfs)
        | assumek fml p0 =>
          angelic_close0 Σe
            (assert_msgs_formulas mfs (assumek fml (solve_evars ε p0 [])))
        | angelicv b p0 =>
          solve_evars (Σe ▻ b) p0 (subst mfs sub_wk1)
        | demonicv b p0 =>
          angelic_close0 Σe (assert_msgs_formulas mfs (demonicv b (solve_evars ε p0 [])))
        | @assert_vareq _ x σ xIn t msg p0 =>
          match Context.catView xIn with
          | isCatLeft bIn =>
            fun t msg p =>
              angelic_close0 Σe
                (assert_msgs_formulas mfs
                   (assert_vareq x t msg (solve_evars ε p [])))
          | isCatRight bIn =>
            fun t _ p =>
              let e := ctx_remove_inctx_right bIn in
              solve_evars (Σe - (x :: σ))
                (eq_rect _ SPath p _ e)
                (subst mfs
                   (eq_rect _ (Sub (Σ ▻▻ Σe)) (sub_single (inctx_cat_right bIn) t) _ e))
          end t msg p0
         | assume_vareq x t p =>
             angelic_close0 Σe
               (assert_msgs_formulas mfs (assume_vareq x t (solve_evars ε p [])))
         | debug b p =>
             angelic_close0 Σe (assert_msgs_formulas mfs (debug b (solve_evars ε p [])))
         end.

      Lemma solve_evars_sound_angelic_binary {Σ0 Σe} (p1 p2 : SPath (Σ0 ▻▻ Σe))
            {mfs : List (Pair Message Formula) (Σ0 ▻▻ Σe)}
            (ι : SymInstance Σ0) :
            (safe (solve_evars Σe p1 mfs) ι <->
             (exists ιe : SymInstance Σe, safe p1 (ι ►► ιe) /\ instpc (map snd mfs) (ι ►► ιe))) ->
            (safe (solve_evars Σe p2 mfs) ι <-> (exists ιe : SymInstance Σe, safe p2 (ι ►► ιe) /\ instpc (map snd mfs) (ι ►► ιe))) ->
            safe (solve_evars Σe p1 mfs) ι \/ safe (solve_evars Σe p2 mfs) ι <->
            (exists ιe : SymInstance Σe, (safe (angelic_binary p1 p2) (ι ►► ιe)) /\ instpc (map snd mfs) (ι ►► ιe)).
      Proof.
        intros H1 H2.
        split.
        + intros [s1|s2];
            apply proj1 in H1;
            apply proj1 in H2.
          * destruct (H1 s1) as (ιe & se1 & Hpc).
            exists ιe. now split; [left|].
          * destruct (H2 s2) as (ιe & se2 & Hpc).
            exists ιe. now split; [right|].
        + intros (ιe & [se1|se2] & Hpc); [left|right];
            apply proj2 in H1;
            apply proj2 in H2;
            [eapply H1|eapply H2];
            now exists ιe.
      Qed.

      Lemma exists_syminstance_nil {P : SymInstance ε -> Prop} :
        (exists (ι : SymInstance ε), P ι) <-> P env_nil.
      Proof.
        split.
        - intros (ι & Pι).
          now destruct (nilView ι).
        - intros Pn. now exists env_nil.
      Qed.

      Lemma exists_syminstance_cons {Σ b} {P : SymInstance (Σ ▻ b) -> Prop} :
        (exists (ι : SymInstance (Σ ▻ b)), P ι) <-> (exists (ι : SymInstance Σ) (v : Lit (snd b)), P (ι ► (b ↦ v))).
      Proof.
        split.
        - intros (ι & Pι).
          destruct (snocView ι) as (ι & v).
          now exists ι, v.
        - intros (ι & v & Pn). now exists (ι ► (b ↦ v)).
      Qed.

      Lemma solve_evars_sound_demonic_binary {Σ0 Σe} (p1 p2 : SPath (Σ0 ▻▻ Σe))
            {mfs : List (Pair Message Formula) (Σ0 ▻▻ Σe)}
            (H2 : forall ι : SymInstance (Σ0 ▻▻ Σe),
               safe (solve_evars ε p2 []) ι <->
               (exists ιe : SymInstance ε, safe p2 (ι ►► ιe)))
            (H1 : forall ι : SymInstance (Σ0 ▻▻ Σe),
                safe (solve_evars ε p1 []) ι <->
                (exists ιe : SymInstance ε, safe p1 (ι ►► ιe)))
            (ι : SymInstance Σ0) :
        safe (solve_evars Σe (demonic_binary p1 p2) mfs) ι <->
         (exists ιe : SymInstance Σe, (safe p1 (ι ►► ιe) /\ safe p2 (ι ►► ιe)) /\ instpc (map snd mfs) (ι ►► ιe)).
      Proof.
        cbn.
        rewrite angelic_close0_sound.
        split.
        - intros (ι0 & sa).
          exists ι0.
          rewrite assert_msgs_formulas_sound in sa.
          destruct sa as (Hpc & sp1 & sp2).
          destruct (proj1 (H1 _) sp1) as (ιe1 & s1).
          destruct (proj1 (H2 _) sp2) as (ιe2 & s2).
          now destruct (nilView ιe1), (nilView ιe2).
        - intros (ιe & (s1 & s2) & Hpc).
          exists ιe.
          rewrite assert_msgs_formulas_sound.
          cbn.
          now rewrite H1, H2, ?exists_syminstance_nil.
      Qed.

      Lemma solve_evars_sound_assumek {Σ0 Σe} (p : SPath (Σ0 ▻▻ Σe))
            (Hp : forall ι : SymInstance (Σ0 ▻▻ Σe),
                safe (solve_evars ε p []) ι <->
                (exists ιe : SymInstance ε, safe p (ι ►► ιe) /\ inst_pathcondition [] (ι ►► ιe)))
            {fml : Formula (Σ0 ▻▻ Σe)}
            {mfs : List (Pair Message Formula) (Σ0 ▻▻ Σe)}
            (ι : SymInstance Σ0) :
            safe (solve_evars Σe (assumek fml p) mfs) ι <->
            (exists ιe : SymInstance Σe, ((inst fml (ι ►► ιe) : Prop) -> safe p (ι ►► ιe)) /\ instpc (map snd mfs) (ι ►► ιe)).
      Proof.
        cbn.
        rewrite angelic_close0_sound.
        setoid_rewrite exists_syminstance_nil in Hp.
        setoid_rewrite assert_msgs_formulas_sound.
        cbn.
        setoid_rewrite Hp.
        change (inst_pathcondition [] _) with True.
        cbn.
        setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
        now setoid_rewrite and_comm at 2.
      Qed.

      Lemma map_snd_subst {Σ Σ' : LCtx} {ζ : Sub Σ Σ'}
            {mfs : List (Pair Message Formula) Σ} :
            map snd (subst mfs ζ) = subst (map snd mfs) ζ.
      Proof.
        induction mfs.
        - easy.
        - cbn.
          rewrite IHmfs.
          now destruct a.
      Qed.

      Lemma exists_and {A : Type} {P : A -> Prop} {Q : Prop} :
        (exists (x : A), P x /\ Q) <-> ((exists (x : A), P x) /\ Q).
      Proof.
        split.
        - intros (x & px & q).
          now split; [exists x|].
        - intros ((x & px) & q).
          now exists x.
      Qed.

      Lemma safe_eq_rect {Σ Σ'} (eq : Σ = Σ') (p : SPath Σ) (ι : SymInstance Σ') :
        safe (eq_rect Σ SPath p Σ' eq) ι = safe p (eq_rect Σ' (fun Σ => SymInstance Σ) ι Σ (eq_sym eq)).
      Proof.
        now destruct eq.
      Qed.

      (* Lemma env_insert_remove {x : 𝑺} {σ : Ty} {Σ0 Σe : LCtx} *)
      (*       (bIn : x :: σ ∈ Σe) : *)
      (*   env_insert bIn *)
      (*     (inst t *)
      (*        (eq_rect (Σ0 ▻▻ Σe - (x :: σ)) (fun Σ : LCtx => SymInstance Σ) (ι ►► env_remove (x :: σ) ιe bIn) *)
      (*           ((Σ0 ▻▻ Σe) - (x :: σ)) (eq_sym (ctx_remove_inctx_right bIn)))) (env_remove (x :: σ) ιe bIn)) *)
      Lemma inst_eq_rect `{Inst AT A} {Σ Σ'} (t : AT Σ) (eq : Σ = Σ') (ι : SymInstance Σ'):
        inst (eq_rect Σ AT t Σ' eq) ι = inst t (eq_rect Σ' (fun Σ => SymInstance Σ) ι Σ (eq_sym eq)).
      Proof.
        now subst.
      Qed.

      Lemma eq_rect_sym1 {A : Type} {P : A -> Type} {a a' : A} (eq : a = a') (v : P a) :
        eq_rect a' P (eq_rect a P v a' eq) a (eq_sym eq) = v.
      Proof.
        now subst.
      Qed.

      Lemma eq_rect_sym2 {A : Type} {P : A -> Type} {a a' : A} (eq : a' = a) (v : P a) :
        eq_rect a' P (eq_rect a P v a' (eq_sym eq)) a eq = v.
      Proof.
        now subst.
      Qed.

      Lemma match_snocView_eq_rect {Σ1 Σ2 b} {R : Type} (eq : Σ1 = Σ2) (E : SymInstance (Σ1 ▻ b))
        (f : SymInstance Σ2 -> Lit (snd b) -> R) :
        match snocView (eq_rect Σ1 (fun Σ => SymInstance (Σ ▻ b)) E Σ2 eq) with
        | isSnoc E v => f E v
        end =
        match snocView E with
        | isSnoc E v => f (eq_rect Σ1 (fun Σ => SymInstance Σ) E Σ2 eq) v
        end.
      Proof.
        now destruct eq.
      Qed.

      Lemma snoc_eq_rect {Σ1 Σ2 b v} (eq : Σ1 = Σ2) (E : SymInstance Σ1) :
        eq_rect Σ1 (fun Σ => SymInstance Σ) E Σ2 eq ► (b ↦ v) =
        eq_rect Σ1 (fun Σ => SymInstance (Σ ▻ b)) (E ► (b ↦ v)) Σ2 eq.
      Proof.
        now destruct eq.
      Qed.

      Lemma env_insert_app {x : 𝑺} {σ : Ty} {Σ0 Σe : LCtx}
            (bIn : x :: σ ∈ Σe) (v : Lit σ)
            {ι : SymInstance Σ0} {ιe : SymInstance (Σe - (x :: σ))} :
            (ι ►► env_insert bIn v ιe) = env_insert (inctx_cat_right bIn) v (eq_rect (Σ0 ▻▻ Σe - (x :: σ)) (fun Σ => SymInstance Σ) (ι ►► ιe) ((Σ0 ▻▻ Σe) - (x :: σ)) (eq_sym (ctx_remove_inctx_right bIn))).
      Proof.
        revert bIn ιe.
        induction Σe; intros bIn ιe;
          try destruct (Context.nilView bIn).
        cbn [env_insert ctx_remove_inctx_right].
        (* can't destruct Contxt.snocView bIn?*)
        destruct bIn as ([|n] & eq).
        - cbn in eq.
          now subst.
        - cbn in ιe.
          destruct (snocView ιe) as (ιe & v').
          change (ctx_remove_inctx_right {| inctx_at := S n; inctx_valid := eq |})
                 with (f_equal (fun f => f b) (eq_trans eq_refl (f_equal ctx_snoc (@ctx_remove_inctx_right _ Σ0 Σe _ {| inctx_at := n; inctx_valid := eq |})))).
          rewrite eq_trans_refl_l.
          cbn.
          rewrite (eq_sym_map_distr (fun f : 𝑺 * Ty -> LCtx => f b)).
          rewrite eq_sym_map_distr.
          rewrite f_equal_compose.
          rewrite (map_subst_map (P := fun x => SymInstance (ctx_snoc x b)) (fun a : LCtx => a ▻ b) (fun _ x => x) ).
          rewrite match_snocView_eq_rect.
          now rewrite IHΣe.
      Qed.

      Lemma env_remove_app {x : 𝑺} {σ : Ty} {Σ0 Σe : LCtx} (bIn : x :: σ ∈ Σe)
        (ι : SymInstance Σ0) (ιe : SymInstance Σe) :
        env_remove (x :: σ) (ι ►► ιe) (inctx_cat_right bIn) =
        eq_rect (Σ0 ▻▻ Σe - (x :: σ)) (fun Σ : LCtx => SymInstance Σ) (ι ►► env_remove (x :: σ) ιe bIn)
                 ((Σ0 ▻▻ Σe) - (x :: σ)) (eq_sym (ctx_remove_inctx_right bIn)).
      Proof.
        revert bIn ιe.
        induction Σe; intros bIn ιe; try destruct (Context.nilView bIn).
        destruct (Context.snocView bIn).
        - now destruct (snocView ιe).
        - destruct (snocView ιe) as (ιe & v).
          change (ctx_remove_inctx_right (inctx_succ i))
                 with (f_equal (fun f => f b) (eq_trans eq_refl (f_equal ctx_snoc (@ctx_remove_inctx_right _ Σ0 Σe _ i)))).
          rewrite eq_trans_refl_l.
          cbn.
          rewrite (eq_sym_map_distr (fun f : 𝑺 * Ty -> LCtx => f b)).
          rewrite eq_sym_map_distr.
          rewrite f_equal_compose.
          rewrite (map_subst_map (P := fun x => SymInstance (ctx_snoc x b)) (fun a : LCtx => a ▻ b) (fun _ x => x) ).
          rewrite IHΣe.
          now rewrite snoc_eq_rect.
      Qed.

      Lemma solve_evars_sound_help {Σ Σe Σ'} (p : SPath Σ') (HeqΣ' : Σ' = Σ ▻▻ Σe)
        (mfs : List (Pair Message Formula) (Σ ▻▻ Σe)) (ι : SymInstance Σ) :
        safe (solve_evars Σe (eq_rect Σ' SPath p (Σ ▻▻ Σe) HeqΣ') mfs) ι <->
        exists ιe : SymInstance Σe,
          safe (eq_rect Σ' SPath p (Σ ▻▻ Σe) HeqΣ') (env_cat ι ιe) /\
          instpc (List.map snd mfs) (env_cat ι ιe).
      Proof.
        revert Σ Σe HeqΣ' mfs ι.
        induction p; intros; subst; cbn.
        - specialize (IHp2 Σ0 Σe eq_refl mfs ι).
          specialize (IHp1 Σ0 Σe eq_refl mfs ι).
          now eapply solve_evars_sound_angelic_binary.
        - specialize (IHp2 (Σ0 ▻▻ Σe) ε eq_refl []).
          specialize (IHp1 (Σ0 ▻▻ Σe) ε eq_refl []).
          setoid_rewrite (base.and_True : forall P, P /\ True <-> P) in IHp1.
          setoid_rewrite (base.and_True : forall P, P /\ True <-> P) in IHp2.
          eauto using solve_evars_sound_demonic_binary, IHp2, IHp1.
       - rewrite angelic_close0_sound.
         setoid_rewrite assert_msgs_formulas_sound.
         setoid_rewrite (base.and_False : forall P, P /\ False <-> False).
         now setoid_rewrite (base.False_and : forall P, False /\ P <-> False).
       - rewrite angelic_close0_sound.
         setoid_rewrite assert_msgs_formulas_sound.
         setoid_rewrite (base.True_and : forall P, True /\ P <-> P).
         now setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
       - setoid_rewrite obligation_equiv.
         specialize (IHp Σ0 Σe eq_refl ((msg :: fml)%ctx :: mfs)%list ι).
         rewrite IHp.
         setoid_rewrite inst_pathcondition_cons.
         setoid_rewrite and_comm at 2.
         setoid_rewrite and_assoc at 1.
         setoid_rewrite and_comm at 3.
         now setoid_rewrite <-and_assoc at 1.
       - specialize (IHp (Σ0 ▻▻ Σe) ε eq_refl []).
         now eapply solve_evars_sound_assumek.
       - specialize (IHp Σ0 (Σe ▻ b) eq_refl (subst mfs sub_wk1) ι).
         cbn in IHp.
         rewrite IHp, exists_syminstance_cons.
         setoid_rewrite map_snd_subst.
         setoid_rewrite inst_subst.
         setoid_rewrite (inst_sub_wk1 (b := b)).
         now setoid_rewrite exists_and.
       - specialize (IHp (Σ0 ▻▻ Σe ▻ b) ε eq_refl []).
         cbn in IHp.
         rewrite angelic_close0_sound.
         setoid_rewrite assert_msgs_formulas_sound.
         cbn.
         setoid_rewrite IHp.
         setoid_rewrite exists_syminstance_nil.
         change (inst_pathcondition [] _) with True.
         setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
         now setoid_rewrite and_comm at 3.
       - destruct (Context.catView xIn).
         + specialize (IHp ((Σ0 ▻▻ Σe) - (x :: σ)) ε eq_refl []).
           rewrite angelic_close0_sound.
           setoid_rewrite assert_msgs_formulas_sound.
           cbn.
           setoid_rewrite obligation_equiv.
           setoid_rewrite IHp.
           setoid_rewrite exists_syminstance_nil.
           cbn.
           change (inst_pathcondition [] _) with True.
           setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
           now setoid_rewrite and_comm at 2.
         + rewrite IHp.
           setoid_rewrite obligation_equiv.
           split.
           * intros (ιe & sp & Hpc).
             unfold inst.
             cbn.
             exists (env_insert bIn (inst (eq_rect ((Σ0 ▻▻ Σe) - (x :: σ)) (fun Σ => Term Σ σ) t (Σ0 ▻▻ Σe - (x :: σ)) (ctx_remove_inctx_right bIn)) (ι ►► ιe)) ιe).
             rewrite env_insert_app, env_remove_insert, env_insert_lookup.
             rewrite inst_subst, inst_sub_shift, env_remove_insert, ?inst_eq_rect.
             rewrite safe_eq_rect in sp.
             repeat split; try assumption.
             rewrite map_snd_subst, inst_subst, inst_eq_rect in Hpc.
             now rewrite inst_sub_single2 in Hpc.
           * intros (ιe & (eq & sp) & Hpc).
             cbn in eq.
             exists (env_remove (x :: σ) ιe bIn).
             rewrite map_snd_subst, inst_subst.
             rewrite safe_eq_rect.
             rewrite env_remove_app in sp.
             split; try assumption.
             rewrite inst_subst, inst_sub_shift in eq.
             rewrite inst_eq_rect.
             rewrite <-env_remove_app.
             now rewrite inst_sub_single.
       - specialize (IHp ((Σ0 ▻▻ Σe) - (x :: σ)) ε eq_refl []).
         rewrite angelic_close0_sound.
         setoid_rewrite assert_msgs_formulas_sound.
         cbn.
         setoid_rewrite IHp.
         cbn.
         setoid_rewrite exists_syminstance_nil.
         cbn.
         change (inst_pathcondition [] _) with True.
         setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
         now setoid_rewrite and_comm at 2.
       - specialize (IHp (Σ0 ▻▻ Σe) ε eq_refl []).
         rewrite angelic_close0_sound.
         setoid_rewrite assert_msgs_formulas_sound.
         cbn.
         setoid_rewrite debug_equiv.
         setoid_rewrite IHp.
         setoid_rewrite exists_syminstance_nil.
         cbn.
         change (inst_pathcondition [] _) with True.
         setoid_rewrite (base.and_True : forall P, P /\ True <-> P).
         now setoid_rewrite and_comm at 2.
      Qed.

      Lemma solve_evars_sound {Σ Σe} (p : SPath (Σ ▻▻ Σe))
        (mfs : List (Pair Message Formula) (Σ ▻▻ Σe)) (ι : SymInstance Σ) :
        safe (solve_evars Σe p mfs) ι <->
        exists ιe : SymInstance Σe,
          safe p (env_cat ι ιe) /\
          instpc (List.map snd mfs) (env_cat ι ιe).
      Proof.
        exact (solve_evars_sound_help p eq_refl mfs ι).
      Qed.

    End Experimental.

  End SPath.
  Notation SPath := SPath.SPath.
  Import SPath.

  Section VerificationConditions.

    Inductive VerificationCondition (p : SPath wnil) : Prop :=
    | vc (P : safe p env_nil).

  End VerificationConditions.

  Definition SDijkstra (A : TYPE) : TYPE :=
    □(A -> SPath) -> SPath.

  Module SDijk.

    Definition pure {A : TYPE} :
      ⊢ A -> SDijkstra A :=
      fun w0 a POST => T POST a.

    Definition map {A B} :
      ⊢ □(A -> B) -> SDijkstra A -> SDijkstra B :=
      fun w0 f m POST => m (comp <$> POST <*> f).

    Definition bind {A B} :
      ⊢ SDijkstra A -> □(A -> SDijkstra B) -> SDijkstra B :=
      fun w0 m f POST => m (fun w1 ω01 a1 => f w1 ω01 a1 (four POST ω01)).

    Definition angelic (x : option 𝑺) σ :
      ⊢ SDijkstra (STerm σ) :=
      fun w k =>
        let y := fresh w x in
        angelicv
          (y :: σ) (k (wsnoc w (y :: σ)) wsnoc_sup (@term_var _ y σ inctx_zero)).
    Global Arguments angelic x σ [w] k.

    Definition angelic_ctx {N : Set} (n : N -> 𝑺) :
      ⊢ ∀ Δ : NCtx N Ty, SDijkstra (fun w => NamedEnv (Term w) Δ) :=
      fix rec {w} Δ {struct Δ} :=
        match Δ with
        | ctx_nil             => fun k => T k env_nil
        | ctx_snoc Δ (x :: σ) =>
          fun k =>
            angelic (Some (n x)) σ (fun w1 ω01 t =>
              rec Δ (fun w2 ω12 EΔ =>
                k w2 (wtrans ω01 ω12) (EΔ ► (x :: σ ↦ subst t ω12))))
        end.
    Global Arguments angelic_ctx {N} n [w] Δ : rename.

    Definition demonic (x : option 𝑺) σ :
      ⊢ SDijkstra (STerm σ) :=
      fun w k =>
        let y := fresh w x in
        demonicv
          (y :: σ) (k (wsnoc w (y :: σ)) wsnoc_sup (@term_var _ y σ inctx_zero)).
    Global Arguments demonic x σ [w] k.

    Definition demonic_ctx {N : Set} (n : N -> 𝑺) :
      ⊢ ∀ Δ : NCtx N Ty, SDijkstra (fun w => NamedEnv (Term w) Δ) :=
      fix demonic_ctx {w} Δ {struct Δ} :=
        match Δ with
        | ctx_nil             => fun k => T k env_nil
        | ctx_snoc Δ (x :: σ) =>
          fun k =>
            demonic (Some (n x)) σ (fun w1 ω01 t =>
              demonic_ctx Δ (fun w2 ω12 EΔ =>
                k w2 (wtrans ω01 ω12) (EΔ ► (x :: σ ↦ subst t ω12))))
        end.
    Global Arguments demonic_ctx {_} n [w] Δ : rename.

    Definition assume_formulas :
      ⊢ List Formula -> SDijkstra Unit :=
      fun w0 fmls0 POST =>
        match Solver.solver fmls0 with
        | Some (existT w1 (ν , fmls1)) =>
          (* Assume variable equalities and the residual constraints *)
          assume_multisub ν
            (assume_formulas_without_solver fmls1
               (* Run POST in the world with the variable and residual
                  formulas included. This is a critical piece of code since
                  this is the place where we really meaningfully change the
                  world. We changed the type of assume_formulas_without_solver
                  just to not forget adding the formulas to the path constraints.
               *)
               (four POST (wmultisub_sup ν) (wformulas_sup w1 fmls1) tt))
        | None =>
          (* The formulas are inconsistent with the path constraints. *)
          block
        end.

    Definition assume_formula :
      ⊢ Formula -> SDijkstra Unit :=
      fun w0 fml0 =>
        assume_formulas (cons fml0 nil).

    Definition assert_formulas :
      ⊢ Message -> List Formula -> SDijkstra Unit :=
      fun w0 msg fmls0 POST =>
        match Solver.solver fmls0 with
        | Some (existT w1 (ν , fmls1)) =>
          (* Assert variable equalities and the residual constraints *)
          assert_multisub msg ν
            (fun msg' =>
               assert_formulas_without_solver msg' fmls1
                 (* Critical code. Like for assume_formulas. *)
                 (four POST (wmultisub_sup ν) (wformulas_sup w1 fmls1) tt))
        | None =>
          (* The formulas are inconsistent with the path constraints. *)
          error (EMsgHere msg)
        end.

    Definition assert_formula :
      ⊢ Message -> Formula -> SDijkstra Unit :=
      fun w0 msg fml0 =>
        assert_formulas msg (cons fml0 nil).

    Definition angelic_binary {A} :
      ⊢ SDijkstra A -> SDijkstra A -> SDijkstra A :=
      fun w m1 m2 POST =>
        angelic_binary (m1 POST) (m2 POST).
    Definition demonic_binary {A} :
      ⊢ SDijkstra A -> SDijkstra A -> SDijkstra A :=
      fun w m1 m2 POST =>
        demonic_binary (m1 POST) (m2 POST).

    Definition angelic_list {A} :
      ⊢ Message -> List A -> SDijkstra A :=
      fun w msg =>
        fix rec xs :=
        match xs with
        | nil        => fun POST => error (EMsgHere msg)
        | cons x xs  => angelic_binary (pure x) (rec xs)
        end.

    Definition demonic_list {A} :
      ⊢ List A -> SDijkstra A :=
      fun w =>
        fix rec xs :=
        match xs with
        | nil        => fun POST => block
        | cons x xs  => demonic_binary (pure x) (rec xs)
        end.

    Definition angelic_finite F `{finite.Finite F} :
      ⊢ Message -> SDijkstra ⌜F⌝ :=
      fun w msg => angelic_list msg (finite.enum F).

    Definition demonic_finite F `{finite.Finite F} :
      ⊢ SDijkstra ⌜F⌝ :=
      fun w => demonic_list (finite.enum F).

    Definition angelic_match_bool' :
      ⊢ Message -> STerm ty_bool -> SDijkstra ⌜bool⌝ :=
      fun _ msg t =>
        angelic_binary
          (fun POST => assert_formula msg (formula_bool t) (fun w1 ω01 _ => POST w1 ω01 true))
          (fun POST => assert_formula msg (formula_bool (term_not t)) (fun w1 ω01 _ => POST w1 ω01 false)).

    Definition angelic_match_bool :
      ⊢ Message -> STerm ty_bool -> SDijkstra ⌜bool⌝ :=
      fun w msg t =>
        match term_get_lit t with
        | Some l => pure  l
        | None   => angelic_match_bool' msg t
        end.

    Definition demonic_match_bool' :
      ⊢ STerm ty_bool -> SDijkstra ⌜bool⌝ :=
      fun _ t =>
        demonic_binary
          (fun POST => assume_formula (formula_bool t) (fun w1 ω01 _ => POST w1 ω01 true))
          (fun POST => assume_formula (formula_bool (term_not t)) (fun w1 ω01 _ => POST w1 ω01 false)).

    Definition demonic_match_bool :
      ⊢ STerm ty_bool -> SDijkstra ⌜bool⌝ :=
      fun w t =>
        match term_get_lit t with
        | Some l => pure  l
        | None   => demonic_match_bool' t
        end.


    (* Definition angelic_match_enum {AT E} : *)
    (*   ⊢ Message -> STerm (ty_enum E) -> (⌜Lit (ty_enum E)⌝ -> □(SPath AT)) -> SPath AT := *)
    (*   fun w msg t k => *)
    (*     match term_get_lit t with *)
    (*     | Some v => T (k v) *)
    (*     | None => angelic_finite *)
    (*                 msg (fun v => assert_formulak msg (formula_eq t (term_enum E v)) (k v)) *)
    (*     end. *)

    (* Definition demonic_match_enum {AT E} : *)
    (*   ⊢ STerm (ty_enum E) -> (⌜Lit (ty_enum E)⌝ -> □(SPath AT)) -> SPath AT := *)
    (*   fun w t k => *)
    (*     match term_get_lit t with *)
    (*     | Some v => T (k v) *)
    (*     | None => demonic_finite *)
    (*                 (fun v => assume_formulak (formula_eq t (term_enum E v)) (k v)) *)
    (*     end. *)

    (* Definition angelic_match_list {AT} (x y : 𝑺) (σ : Ty) : *)
    (*   ⊢ Message -> STerm (ty_list σ) -> □(SPath AT) -> □(STerm σ -> STerm (ty_list σ) -> SPath AT) -> SPath AT := *)
    (*   fun w0 msg t knil kcons => *)
    (*     angelic_binary (assert_formulak msg (formula_eq (term_lit (ty_list σ) []) t) knil) *)
    (*       (angelic x σ *)
    (*          (fun w1 ω01 (th : Term w1 σ) => *)
    (*           angelic y (ty_list σ) *)
    (*             (fun w2 ω12 (tt : Term w2 (ty_list σ)) => *)
    (*              assert_formulak (subst msg (wtrans ω01 ω12)) *)
    (*                (formula_eq (term_binop binop_cons (subst th ω12) tt) (subst t (wtrans ω01 ω12))) *)
    (*                (fun w3 ω23 => *)
    (*                 four kcons (wtrans ω01 ω12) ω23 (subst th (wtrans ω12 ω23)) (subst tt ω23))))). *)

    (* Definition demonic_match_list {AT} (x y : 𝑺) (σ : Ty) : *)
    (*   ⊢ STerm (ty_list σ) -> □(SPath AT) -> □(STerm σ -> STerm (ty_list σ) -> SPath AT) -> SPath AT := *)
    (*   fun w0 t knil kcons => *)
    (*     demonic_binary (assume_formulak (formula_eq (term_lit (ty_list σ) []) t) knil) *)
    (*       (demonic x σ *)
    (*          (fun w1 ω01 (th : Term w1 σ) => *)
    (*           demonic y (ty_list σ) *)
    (*             (fun w2 ω12 (tt : Term w2 (ty_list σ)) => *)
    (*              assume_formulak *)
    (*                (formula_eq (term_binop binop_cons (subst th ω12) tt) (subst t (wtrans ω01 ω12))) *)
    (*                (fun w3 ω23 => *)
    (*                 four kcons (wtrans ω01 ω12) ω23 (subst th (wtrans ω12 ω23)) (subst tt ω23))))). *)

    Definition angelic_match_sum {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) :
      ⊢ Message -> STerm (ty_sum σ τ) -> □(STerm σ -> SDijkstra A) -> □(STerm τ -> SDijkstra A) -> SDijkstra A.
    Proof.
      intros w0 msg t kinl kinr.
      apply angelic_binary.
      - eapply bind.
        apply (angelic (Some x) σ).
        intros w1 ω01 t1.
        eapply bind.
        apply assert_formula. apply (subst msg ω01).
        apply (formula_eq (term_inl t1) (subst t ω01)).
        intros w2 ω12 _.
        apply (four kinl ω01). auto.
        apply (persist__term t1 ω12).
      - eapply bind.
        apply (angelic (Some y) τ).
        intros w1 ω01 t1.
        eapply bind.
        apply assert_formula. apply (subst msg ω01).
        apply (formula_eq (term_inr t1) (subst t ω01)).
        intros w2 ω12 _.
        apply (four kinr ω01). auto.
        apply (persist__term t1 ω12).
    Defined.

    (* Definition angelic_match_sum {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) : *)
    (*   ⊢ Message -> STerm (ty_sum σ τ) -> □(STerm σ -> SDijkstra A) -> □(STerm τ -> SDijkstra A) -> SDijkstra A. *)
    (* Proof. *)
    (*   intros w0. *)
    (*   fun w0 msg t kinl kinr => *)
    (*     match term_get_sum t with *)
    (*     | Some (inl tσ) => T kinl tσ *)
    (*     | Some (inr tτ) => T kinr tτ *)
    (*     | None => angelic_match_sum' x y msg t kinl kinr *)
    (*     end. *)

    Definition demonic_match_sum' {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) :
      ⊢ STerm (ty_sum σ τ) -> □(STerm σ -> SDijkstra A) -> □(STerm τ -> SDijkstra A) -> SDijkstra A.
    Proof.
      intros w0 t kinl kinr.
      apply demonic_binary.
      - eapply bind.
        apply (demonic (Some x) σ).
        intros w1 ω01 t1.
        eapply bind.
        apply assume_formula.
        apply (formula_eq (term_inl t1) (subst t ω01)).
        intros w2 ω12 _.
        apply (four kinl ω01). auto.
        apply (persist__term t1 ω12).
      - eapply bind.
        apply (demonic (Some y) τ).
        intros w1 ω01 t1.
        eapply bind.
        apply assume_formula.
        apply (formula_eq (term_inr t1) (subst t ω01)).
        intros w2 ω12 _.
        apply (four kinr ω01). auto.
        apply (persist__term t1 ω12).
    Defined.

    Definition demonic_match_sum {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) :
      ⊢ STerm (ty_sum σ τ) -> □(STerm σ -> SDijkstra A) -> □(STerm τ -> SDijkstra A) -> SDijkstra A :=
      fun w0 t kinl kinr =>
        match term_get_sum t with
        | Some (inl tσ) => T kinl tσ
        | Some (inr tτ) => T kinr tτ
        | None => demonic_match_sum' x y t kinl kinr
        end.

    Definition angelic_match_prod {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) :
      ⊢ Message -> STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SDijkstra A) -> SDijkstra A.
    Proof.
      intros w0 msg t k.
      eapply bind.
      apply (angelic (Some x) σ).
      intros w1 ω01 t1.
      eapply bind.
      apply (angelic (Some y) τ).
      intros w2 ω12 t2.
      eapply bind.
      apply assert_formula. apply (subst msg (wtrans ω01 ω12)).
      refine (formula_eq _ (subst t (wtrans ω01 ω12))).
      eapply (term_binop binop_pair).
      apply (persist__term t1 ω12).
      apply t2.
      intros w3 ω23 _.
      apply (four k (wtrans ω01 ω12)).
      auto.
      apply (persist__term t1 (wtrans ω12 ω23)).
      apply (persist__term t2 ω23).
    Defined.

    (* Definition angelic_match_prod {AT} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) : *)
    (*   ⊢ Message -> STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SPath AT) -> SPath AT := *)
    (*   fun w0 msg t k => *)
    (*     match term_get_pair t with *)
    (*     | Some (tσ,tτ) => T k tσ tτ *)
    (*     | None => angelic_match_prod' x y msg t k *)
    (*     end. *)

    Definition demonic_match_prod {A} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) :
      ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SDijkstra A) -> SDijkstra A.
    Proof.
      intros w0 t k.
      eapply bind.
      apply (demonic (Some x) σ).
      intros w1 ω01 t1.
      eapply bind.
      apply (demonic (Some y) τ).
      intros w2 ω12 t2.
      eapply bind.
      apply assume_formula.
      refine (formula_eq _ (subst t (wtrans ω01 ω12))).
      eapply (term_binop binop_pair).
      apply (persist__term t1 ω12).
      apply t2.
      intros w3 ω23 _.
      apply (four k (wtrans ω01 ω12)).
      auto.
      apply (persist__term t1 (wtrans ω12 ω23)).
      apply (persist__term t2 ω23).
    Defined.

    (* Definition demonic_match_prod {AT} (x : 𝑺) (σ : Ty) (y : 𝑺) (τ : Ty) : *)
    (*   ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SPath AT) -> SPath AT := *)
    (*   fun w0 t k => *)
    (*     match term_get_pair t with *)
    (*     | Some (tσ,tτ) => T k tσ tτ *)
    (*     | None => demonic_match_prod' x y t k *)
    (*     end. *)

    (* Definition angelic_match_record' {N : Set} (n : N -> 𝑺) {AT R} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) : *)
    (*   ⊢ Message -> STerm (ty_record R) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 msg t k. *)
    (*   apply (angelic_freshen_ctx n Δ). *)
    (*   intros w1 ω01 ts. *)
    (*   apply assert_formulak. *)
    (*   apply (subst msg ω01). *)
    (*   apply (formula_eq (subst t ω01)). *)
    (*   apply (term_record R (record_pattern_match_env_reverse p ts)). *)
    (*   intros w2 ω12. *)
    (*   apply (k w2 (wtrans ω01 ω12) (subst ts ω12)). *)
    (* Defined. *)

    (* Definition angelic_match_record {N : Set} (n : N -> 𝑺) {AT R} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) : *)
    (*   ⊢ Message -> STerm (ty_record R) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 msg t k. *)
    (*   destruct (term_get_record t). *)
    (*   - apply (T k). *)
    (*     apply (record_pattern_match_env p n0). *)
    (*   - apply (angelic_match_record' n p msg t k). *)
    (* Defined. *)

    (* Definition demonic_match_record' {N : Set} (n : N -> 𝑺) {AT R} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) : *)
    (*   ⊢ STerm (ty_record R) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 t k. *)
    (*   apply (demonic_ctx n Δ). *)
    (*   intros w1 ω01 ts. *)
    (*   apply assume_formulak. *)
    (*   apply (formula_eq (subst t ω01)). *)
    (*   apply (term_record R (record_pattern_match_env_reverse p ts)). *)
    (*   intros w2 ω12. *)
    (*   apply (k w2 (wtrans ω01 ω12) (subst ts ω12)). *)
    (* Defined. *)

    (* Definition demonic_match_record {N : Set} (n : N -> 𝑺) {AT R} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) : *)
    (*   ⊢ STerm (ty_record R) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 t k. *)
    (*   destruct (term_get_record t). *)
    (*   - apply (T k). *)
    (*     apply (record_pattern_match_env p n0). *)
    (*   - apply (demonic_match_record' n p t k). *)
    (* Defined. *)

    (* Definition angelic_match_tuple' {N : Set} (n : N -> 𝑺) {AT σs} {Δ : NCtx N Ty} (p : TuplePat σs Δ) : *)
    (*   ⊢ Message -> STerm (ty_tuple σs) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 msg t k. *)
    (*   apply (angelic_freshen_ctx n Δ). *)
    (*   intros w1 ω01 ts. *)
    (*   apply assert_formulak. *)
    (*   apply (subst msg ω01). *)
    (*   apply (formula_eq (subst t ω01)). *)
    (*   apply (term_tuple (tuple_pattern_match_env_reverse p ts)). *)
    (*   intros w2 ω12. *)
    (*   apply (k w2 (wtrans ω01 ω12) (subst ts ω12)). *)
    (* Defined. *)

    (* Definition angelic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs} {Δ : NCtx N Ty} (p : TuplePat σs Δ) : *)
    (*   ⊢ Message -> STerm (ty_tuple σs) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 msg t k. *)
    (*   destruct (term_get_tuple t). *)
    (*   - apply (T k). *)
    (*     apply (tuple_pattern_match_env p e). *)
    (*   - apply (angelic_match_tuple' n p msg t k). *)
    (* Defined. *)

    (* Definition demonic_match_tuple' {N : Set} (n : N -> 𝑺) {AT σs} {Δ : NCtx N Ty} (p : TuplePat σs Δ) : *)
    (*   ⊢ STerm (ty_tuple σs) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 t k. *)
    (*   apply (demonic_ctx n Δ). *)
    (*   intros w1 ω01 ts. *)
    (*   apply assume_formulak. *)
    (*   apply (formula_eq (subst t ω01)). *)
    (*   apply (term_tuple (tuple_pattern_match_env_reverse p ts)). *)
    (*   intros w2 ω12. *)
    (*   apply (k w2 (wtrans ω01 ω12) (subst ts ω12)). *)
    (* Defined. *)

    (* Definition demonic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs} {Δ : NCtx N Ty} (p : TuplePat σs Δ) : *)
    (*   ⊢ STerm (ty_tuple σs) -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT. *)
    (* Proof. *)
    (*   intros w0 t k. *)
    (*   destruct (term_get_tuple t). *)
    (*   - apply (T k). *)
    (*     apply (tuple_pattern_match_env p e). *)
    (*   - apply (demonic_match_tuple' n p t k). *)
    (* Defined. *)

    (* (* TODO: move to Syntax *) *)
    (* Definition pattern_match_env_reverse {N : Set} {Σ : LCtx} {σ : Ty} {Δ : NCtx N Ty} (p : Pattern Δ σ) : *)
    (*   NamedEnv (Term Σ) Δ -> Term Σ σ := *)
    (*   match p with *)
    (*   | pat_var x    => fun Ex => match snocView Ex with isSnoc _ t => t end *)
    (*   | pat_unit     => fun _ => term_lit ty_unit tt *)
    (*   | pat_pair x y => fun Exy => match snocView Exy with *)
    (*                                  isSnoc Ex ty => *)
    (*                                  match snocView Ex with *)
    (*                                    isSnoc _ tx => term_binop binop_pair tx ty *)
    (*                                  end *)
    (*                                end *)
    (*   | pat_tuple p  => fun EΔ => term_tuple (tuple_pattern_match_env_reverse p EΔ) *)
    (*   | pat_record p => fun EΔ => term_record _ (record_pattern_match_env_reverse p EΔ) *)
    (*   end. *)

    (* Definition angelic_match_pattern {N : Set} (n : N -> 𝑺) {AT σ} {Δ : NCtx N Ty} (p : Pattern Δ σ) : *)
    (*   ⊢ Message -> STerm σ -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT := *)
    (*   fun w0 msg t k => *)
    (*     angelic_freshen_ctx n Δ *)
    (*       (fun w1 ω01 (ts : (fun Σ : LCtx => NamedEnv (Term Σ) Δ) w1) => *)
    (*        assert_formulak (subst msg ω01) (formula_eq (subst t ω01) (pattern_match_env_reverse p ts)) *)
    (*          (fun w2 ω12 => k w2 (wtrans ω01 ω12) (subst ts ω12))). *)

    (* Definition demonic_match_pattern {N : Set} (n : N -> 𝑺) {AT σ} {Δ : NCtx N Ty} (p : Pattern Δ σ) : *)
    (*   ⊢ STerm σ -> □((fun Σ => NamedEnv (Term Σ) Δ) -> SPath AT) -> SPath AT := *)
    (*   fun w0 t k => *)
    (*     demonic_ctx n Δ *)
    (*       (fun w1 ω01 (ts : (fun Σ : LCtx => NamedEnv (Term Σ) Δ) w1) => *)
    (*        assume_formulak (formula_eq (subst t ω01) (pattern_match_env_reverse p ts)) *)
    (*          (fun w2 ω12 => k w2 (wtrans ω01 ω12) (subst ts ω12))). *)

    (* Definition angelic_match_union' {N : Set} (n : N -> 𝑺) {AT U} {Δ : 𝑼𝑲 U -> NCtx N Ty} *)
    (*   (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) : *)
    (*   ⊢ Message -> STerm (ty_union U) -> (∀ K, □((fun Σ => NamedEnv (Term Σ) (Δ K)) -> SPath AT)) -> SPath AT := *)
    (*   fun w0 msg t k => *)
    (*     angelic_finite msg *)
    (*       (fun K : 𝑼𝑲 U => *)
    (*        angelic None (𝑼𝑲_Ty K) *)
    (*          (fun w1 ω01 (t__field : Term w1 (𝑼𝑲_Ty K)) => *)
    (*           assert_formulak (subst msg ω01) (formula_eq (term_union U K t__field) (subst t ω01)) *)
    (*             (fun w2 ω12 => *)
    (*              let ω02 := wtrans ω01 ω12 in *)
    (*              angelic_match_pattern n (p K) (subst msg ω02) (subst t__field ω12) (four (k K) ω02)))). *)

    (* Definition angelic_match_union {N : Set} (n : N -> 𝑺) {AT U} {Δ : 𝑼𝑲 U -> NCtx N Ty} *)
    (*   (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) : *)
    (*   ⊢ Message -> STerm (ty_union U) -> (∀ K, □((fun Σ => NamedEnv (Term Σ) (Δ K)) -> SPath AT)) -> SPath AT := *)
    (*   fun w0 msg t k => *)
    (*     match term_get_union t with *)
    (*     | Some (existT K t__field) => angelic_match_pattern n (p K) msg t__field (k K) *)
    (*     | None => angelic_match_union' n p msg t k *)
    (*     end. *)

    (* Definition demonic_match_union' {N : Set} (n : N -> 𝑺) {AT U} {Δ : 𝑼𝑲 U -> NCtx N Ty} *)
    (*   (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) : *)
    (*   ⊢ STerm (ty_union U) -> (∀ K, □((fun Σ => NamedEnv (Term Σ) (Δ K)) -> SPath AT)) -> SPath AT := *)
    (*   fun w0 t k => *)
    (*     demonic_finite *)
    (*       (fun K : 𝑼𝑲 U => *)
    (*        demonic None (𝑼𝑲_Ty K) *)
    (*          (fun w1 ω01 (t__field : Term w1 (𝑼𝑲_Ty K)) => *)
    (*           assume_formulak (formula_eq (term_union U K t__field) (subst t ω01)) *)
    (*             (fun w2 ω12 => *)
    (*              demonic_match_pattern n (p K) (subst t__field ω12) (four (k K) (wtrans ω01 ω12))))). *)

    (* Definition demonic_match_union {N : Set} (n : N -> 𝑺) {AT U} {Δ : 𝑼𝑲 U -> NCtx N Ty} *)
    (*   (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) : *)
    (*   ⊢ STerm (ty_union U) -> (∀ K, □((fun Σ => NamedEnv (Term Σ) (Δ K)) -> SPath AT)) -> SPath AT := *)
    (*   fun w0 t k => *)
    (*     match term_get_union t with *)
    (*     | Some (existT K t__field) => demonic_match_pattern n (p K) t__field (k K) *)
    (*     | None => demonic_match_union' n p t k *)
    (*     end. *)

    Lemma and_iff_compat_l' (A B C : Prop) :
      (A -> B <-> C) <-> (A /\ B <-> A /\ C).
    Proof. intuition. Qed.

    Lemma imp_iff_compat_l' (A B C : Prop) :
      (A -> B <-> C) <-> ((A -> B) <-> (A -> C)).
    Proof. intuition. Qed.

    Global Instance proper_debug {B} : Proper (eq ==> iff ==> iff) (@Debug B).
    Proof.
      unfold Proper, respectful.
      intros ? ? -> P Q PQ.
      split; intros []; constructor; intuition.
    Qed.

    (* Ltac wsimpl := *)
    (*   repeat *)
    (*     (try change (wctx (wsnoc ?w ?b)) with (ctx_snoc (wctx w) b); *)
    (*      try change (wsub (@wred_sup ?w ?b ?t)) with (sub_snoc (sub_id (wctx w)) b t); *)
    (*      try change (wco (wsnoc ?w ?b)) with (subst (wco w) (sub_wk1 (b:=b))); *)
    (*      try change (wsub (@wrefl ?w)) with (sub_id (wctx w)); *)
    (*      try change (wsub (@wsnoc_sup ?w ?b)) with (@sub_wk1 (wctx w) b); *)
    (*      try change (wctx (wformula ?w ?fml)) with (wctx w); *)
    (*      try change (wsub (wtrans ?ω1 ?ω2)) with (subst (wsub ω1) (wsub ω2)); *)
    (*      try change (wsub (@wformula_sup ?w ?fml)) with (sub_id (wctx w)); *)
    (*      try change (wco (wformula ?w ?fml)) with (cons fml (wco w)); *)
    (*      try change (wco (@wsubst ?w _ _ ?xIn ?t)) with (subst (wco w) (sub_single xIn t)); *)
    (*      try change (wctx (@wsubst ?w _ _ ?xIn ?t)) with (ctx_remove xIn); *)
    (*      try change (wsub (@wsubst_sup ?w _ _ ?xIn ?t)) with (sub_single xIn t); *)
    (*      rewrite <- ?sub_comp_wk1_tail, ?inst_subst, ?subst_sub_id, *)
    (*        ?inst_sub_id, ?inst_sub_wk1, ?inst_sub_snoc, *)
    (*        ?inst_lift, ?inst_sub_single, ?inst_pathcondition_cons; *)
    (*      repeat *)
    (*        match goal with *)
    (*        | |- Debug _ _ <-> Debug _ _ => apply proper_debug *)
    (*        | |- (?A /\ ?B) <-> (?A /\ ?C) => apply and_iff_compat_l'; intro *)
    (*        | |- (?A -> ?B) <-> (?A -> ?C) => apply imp_iff_compat_l'; intro *)
    (*        | |- (exists x : ?X, _) <-> (exists y : ?X, _) => apply base.exist_proper; intro *)
    (*        | |- (forall x : ?X, _) <-> (forall y : ?X, _) => apply base.forall_proper; intro *)
    (*        | |- wp ?m _ ?ι -> wp ?m _ ?ι => apply wp_monotonic; intro *)
    (*        | |- wp ?m _ ?ι <-> wp ?m _ ?ι => apply wp_equiv; intro *)
    (*        | |- ?w ⊒ ?w => apply wrefl *)
    (*        | |- ?POST (@inst _ _ _ ?Σ1 ?x1 ?ι1) <-> ?POST (@inst _ _ _ ?Σ2 ?x2 ?ι2) => *)
    (*          assert (@inst _ _ _ Σ1 x1 ι1 = @inst _ _ _ Σ2 x2 ι2) as ->; auto *)
    (*        | |- ?POST (?inst _ _ _ ?Σ1 ?x1 ?ι1) -> ?POST (@inst _ _ _ ?Σ2 ?x2 ?ι2) => *)
    (*          assert (@inst _ _ _ Σ1 x1 ι1 = @inst _ _ _ Σ2 x2 ι2) as ->; auto *)
    (*        | Hdcl : mapping_dcl ?f |- *)
    (*          inst (?f ?w ?ω _) _ = inst (?f ?w ?ω _) _ => *)
    (*          apply (Hdcl w ω w ω wrefl) *)
    (*        | Hdcl : mapping_dcl ?f |- *)
    (*          inst (?f ?w0 wrefl _) _ = inst (?f ?w1 ?ω01 _) _ => *)
    (*          apply (Hdcl w0 wrefl w1 ω01 ω01) *)
    (*        | Hdcl : mapping_dcl ?f |- *)
    (*          inst (?f ?w1 ?ω01 _) _ = inst (?f ?w0 wrefl _) _ => *)
    (*          symmetry; apply (Hdcl w0 wrefl w1 ω01 ω01) *)
    (*        | Hdcl : arrow_dcl ?f |- *)
    (*          wp (?f ?w ?ω _) _ _ -> wp (?f ?w ?ω _) _ _  => *)
    (*          apply (Hdcl w ω w ω wrefl) *)
    (*        end). *)

  End SDijk.

  Section Configuration.

    Record Config : Type :=
      MkConfig
        { config_debug_function : forall Δ τ, 𝑭 Δ τ -> bool;
        }.

    Definition default_config : Config :=
      {| config_debug_function _ _ f := false;
      |}.

  End Configuration.

  Definition SMut (Γ1 Γ2 : PCtx) (A : TYPE) : TYPE :=
    □(A -> SStore Γ2 -> SHeap -> SPath) -> SStore Γ1 -> SHeap -> SPath.
  Bind Scope smut_scope with SMut.

  Module SMut.

    Section Basic.

      Definition dijkstra {Γ} {A : TYPE} :
        ⊢ SDijkstra A -> SMut Γ Γ A.
      Proof.
        intros w0 m POST δ0 h0.
        apply m.
        intros w1 ω01 a1.
        apply POST; auto.
        apply (subst δ0 ω01).
        apply (subst h0 ω01).
      Defined.

      Definition pure {Γ} {A : TYPE} :
        ⊢ A -> SMut Γ Γ A.
      Proof.
        intros w0 a k.
        apply k; auto. apply wrefl.
      Defined.

      Definition bind {Γ1 Γ2 Γ3 A B} :
        ⊢ SMut Γ1 Γ2 A -> □(A -> SMut Γ2 Γ3 B) -> SMut Γ1 Γ3 B.
      Proof.
        intros w0 ma f k.
        unfold SMut, Impl, Box in *.
        apply ma; auto.
        intros w1 ω01 a1.
        apply f; auto.
        apply (four k ω01).
      Defined.

      Definition bind_box {Γ1 Γ2 Γ3 A B} :
        ⊢ □(SMut Γ1 Γ2 A) -> □(A -> SMut Γ2 Γ3 B) -> □(SMut Γ1 Γ3 B) :=
        fun w0 m f => bind <$> m <*> four f.

      (* Definition strength {Γ1 Γ2 A B Σ} `{Subst A, Subst B} (ma : SMut Γ1 Γ2 A Σ) (b : B Σ) : *)
      (*   SMut Γ1 Γ2 (fun Σ => A Σ * B Σ)%type Σ := *)
      (*   bind ma (fun _ ζ a => pure (a, subst b ζ)). *)

      Definition bind_right {Γ1 Γ2 Γ3 A B} :
        ⊢ SMut Γ1 Γ2 A -> □(SMut Γ2 Γ3 B) -> SMut Γ1 Γ3 B.
      Proof.
        intros w0 m k POST.
        apply m.
        intros w1 ω01 a1.
        apply k. auto.
        intros w2 ω12 b2.
        apply (four POST ω01); auto.
      Defined.

      (* Definition bind_left {Γ1 Γ2 Γ3 A B} `{Subst A} : *)
      (*   ⊢ □(SMut Γ1 Γ2 A) -> □(SMut Γ2 Γ3 B) -> □(SMut Γ1 Γ3 A). *)
      (* Proof. *)
      (*   intros w0 ma mb. *)
      (*   apply (bbind ma). *)
      (*   intros w1 ω01 a1 δ1 h1. *)
      (*   apply (bind (mb w1 ω01 δ1 h1)). *)
      (*   intros w2 ω12 [_ δ2 h2]. *)
      (*   apply (pure). *)
      (*   apply (subst a1 ω12). *)
      (*   auto. *)
      (*   auto. *)
      (* Defined. *)

      (* Definition map {Γ1 Γ2 A B} `{Subst A, Subst B} : *)
      (*   ⊢ □(SMut Γ1 Γ2 A) -> □(A -> B) -> □(SMut Γ1 Γ2 B) := *)
      (*   fun w0 ma f Σ1 ζ01 pc1 δ1 h1 => *)
      (*     map pc1 *)
      (*       (fun Σ2 ζ12 pc2 '(MkSMutResult a2 δ2 h2) => *)
      (*          MkSMutResult (f Σ2 (subst ζ01 ζ12) pc2 a2) δ2 h2) *)
      (*        (ma Σ1 ζ01 pc1 δ1 h1). *)

      Definition error {Γ1 Γ2 A D} (func : string) (msg : string) (data:D) :
        ⊢ SMut Γ1 Γ2 A :=
        fun w _ δ h =>
          error
            (EMsgHere
               {| msg_function := func;
                  msg_message := msg;
                  msg_program_context := Γ1;
                  msg_localstore := δ;
                  msg_heap := h;
                  msg_pathcondition := wco w
               |}).
      Global Arguments error {_ _ _ _} func msg data {w} _ _.

      Definition block {Γ1 Γ2 A} :
        ⊢ SMut Γ1 Γ2 A.
      Proof.
        intros w0 POST δ h.
        apply block.
      Defined.

      Definition angelic_binary {Γ1 Γ2 A} :
        ⊢ SMut Γ1 Γ2 A -> SMut Γ1 Γ2 A -> SMut Γ1 Γ2 A :=
        fun w m1 m2 POST δ1 h1 =>
          angelic_binary (m1 POST δ1 h1) (m2 POST δ1 h1).
      Definition demonic_binary {Γ1 Γ2 A} :
        ⊢ SMut Γ1 Γ2 A -> SMut Γ1 Γ2 A -> SMut Γ1 Γ2 A :=
        fun w m1 m2 POST δ1 h1 =>
          demonic_binary (m1 POST δ1 h1) (m2 POST δ1 h1).

      Definition angelic_list {A Γ} :
        ⊢ (SStore Γ -> SHeap -> Message) -> List A -> SMut Γ Γ A :=
        fun w msg xs POST δ h => dijkstra (SDijk.angelic_list (msg δ h) xs) POST δ h.

      Definition angelic_finite {Γ} F `{finite.Finite F} :
        ⊢ (SStore Γ -> SHeap -> Message) -> SMut Γ Γ ⌜F⌝ :=
        fun w msg POST δ h => dijkstra (SDijk.angelic_finite (msg δ h)) POST δ h.

      Definition demonic_finite {Γ} F `{finite.Finite F} :
        ⊢ SMut Γ Γ ⌜F⌝ :=
        fun w => dijkstra (SDijk.demonic_finite (w:=w)).

      Definition angelic {Γ} (x : option 𝑺) σ :
        ⊢ SMut Γ Γ (STerm σ) :=
        fun w => dijkstra (SDijk.angelic x σ (w:=w)).
      Global Arguments angelic {Γ} x σ {w}.

      Definition demonic {Γ} (x : option 𝑺) σ :
        ⊢ SMut Γ Γ (STerm σ) :=
        fun w => dijkstra (SDijk.demonic x σ (w:=w)).
      Global Arguments demonic {Γ} x σ {w}.

      Definition debug {AT DT D} `{Subst DT, Inst DT D, OccursCheck DT} {Γ1 Γ2} :
        ⊢ (SStore Γ1 -> SHeap -> DT) -> (SMut Γ1 Γ2 AT) -> (SMut Γ1 Γ2 AT).
      Proof.
        intros w0 d m POST δ h.
        eapply debug. eauto.
        eauto. eauto.
        apply d. auto. auto.
        apply m; auto.
      Defined.

      Definition angelic_ctx {N : Set} (n : N -> 𝑺) {Γ} :
        ⊢ ∀ Δ : NCtx N Ty, SMut Γ Γ (fun w => NamedEnv (Term w) Δ).
      Proof.
        intros w0 Δ. apply dijkstra.
        apply (SDijk.angelic_ctx n Δ).
      Defined.
      Global Arguments angelic_ctx {N} n {Γ} [w] Δ : rename.

      Definition demonic_ctx {N : Set} (n : N -> 𝑺) {Γ} :
        ⊢ ∀ Δ : NCtx N Ty, SMut Γ Γ (fun w => NamedEnv (Term w) Δ).
      Proof.
        intros w0 Δ. apply dijkstra.
        apply (SDijk.demonic_ctx n Δ).
      Defined.
      Global Arguments demonic_ctx {N} n {Γ} [w] Δ : rename.

    End Basic.

    Module SMutNotations.

      (* Notation "'⨂' x .. y => F" := *)
      (*   (smut_demonic (fun x => .. (smut_demonic (fun y => F)) .. )) : smut_scope. *)

      (* Notation "'⨁' x .. y => F" := *)
      (*   (smut_angelic (fun x => .. (smut_angelic (fun y => F)) .. )) : smut_scope. *)

      (* Infix "⊗" := smut_demonic_binary (at level 40, left associativity) : smut_scope. *)
      (* Infix "⊕" := smut_angelic_binary (at level 50, left associativity) : smut_scope. *)

      Notation "x <- ma ;; mb" := (bind ma (fun _ _ x => mb)) (at level 80, ma at level 90, mb at level 200, right associativity) : smut_scope.
      Notation "ma >>= f" := (bind ma f) (at level 50, left associativity) : smut_scope.
      Notation "ma >> mb" := (bind_right ma mb) (at level 50, left associativity) : smut_scope.
      (* Notation "m1 ;; m2" := (smut_bind_right m1 m2) : smut_scope. *)

    End SMutNotations.
    Import SMutNotations.
    Local Open Scope smut_scope.

    Section AssumeAssert.

      (* Add the provided formula to the path condition. *)
      Definition assume_formula {Γ} :
        ⊢ Formula -> SMut Γ Γ Unit.
      Proof.
        intros w0 fml. apply dijkstra.
        apply (SDijk.assume_formula fml).
      Defined.

      Definition box_assume_formula {Γ} :
        ⊢ Formula -> □(SMut Γ Γ Unit) :=
        fun w0 fml => assume_formula <$> persist fml.

      Definition assert_formula {Γ} :
        ⊢ Formula -> SMut Γ Γ Unit :=
        fun w0 fml POST δ0 h0 =>
          dijkstra
            (SDijk.assert_formula
               {| msg_function := "smut_assert_formula";
                  msg_message := "Proof obligation";
                  msg_program_context := Γ;
                  msg_localstore := δ0;
                  msg_heap := h0;
                  msg_pathcondition := wco w0
               |} fml)
            POST δ0 h0.

      Definition box_assert_formula {Γ} :
        ⊢ Formula -> □(SMut Γ Γ Unit) :=
        fun w0 fml => assert_formula <$> persist fml.

      Definition assert_formulas {Γ} :
        ⊢ List Formula -> SMut Γ Γ Unit.
      Proof.
        intros w0 fmls POST δ0 h0.
        eapply dijkstra.
        apply SDijk.assert_formulas.
        apply
          {| msg_function := "smut_assert_formula";
             msg_message := "Proof obligation";
             msg_program_context := Γ;
             msg_localstore := δ0;
             msg_heap := h0;
             msg_pathcondition := wco w0
          |}.
        apply fmls.
        apply POST.
        apply δ0.
        apply h0.
      Defined.

    End AssumeAssert.

    Section PatternMatching.

      (* Definition angelic_match_bool {Γ} : *)
      (*   ⊢ STerm ty_bool -> SMut Γ Γ ⌜bool⌝ := *)
      (*   fun w t POST δ h => *)
      (*     dijkstra *)
      (*       (SDijk.angelic_match_bool *)
      (*          {| msg_function := "SMut.angelic_match_bool"; *)
      (*             msg_message := "pattern match assertion"; *)
      (*             msg_program_context := Γ; *)
      (*             msg_localstore := δ; *)
      (*             msg_heap := h; *)
      (*             msg_pathcondition := wco w *)
      (*          |} t) *)
      (*       POST δ h. *)

      (* Definition demonic_match_bool {Γ} : *)
      (*   ⊢ STerm ty_bool -> SMut Γ Γ ⌜bool⌝ := *)
      (*   fun w t => dijkstra (SDijk.demonic_match_bool t). *)

      Definition angelic_match_bool' {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t kt kf.
        apply angelic_binary.
        - eapply bind_right.
          apply assert_formula.
          (* apply *)
          (*   {| msg_function        := "smut_angelic_match_bool"; *)
          (*      msg_message         := "pattern match assertion"; *)
          (*      msg_program_context := Γ1; *)
          (*      msg_localstore      := δ0; *)
          (*      msg_heap            := h0; *)
          (*      msg_pathcondition   := wco w0; *)
          (*   |}. *)
          apply (formula_bool t).
          apply kt.
        - eapply bind_right.
          apply assert_formula.
          (* apply *)
          (*   {| msg_function        := "smut_angelic_match_bool"; *)
          (*      msg_message         := "pattern match assertion"; *)
          (*      msg_program_context := Γ1; *)
          (*      msg_localstore      := δ0; *)
          (*      msg_heap            := h0; *)
          (*      msg_pathcondition   := wco w0; *)
          (*   |}. *)
          apply (formula_bool (term_not t)).
          apply kf.
      Defined.

      Definition angelic_match_bool {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT :=
        fun w0 t kt kf =>
          match term_get_lit t with
          | Some true => T kt
          | Some false => T kf
          | None => angelic_match_bool' t kt kf
          end.

      Definition box_angelic_match_bool {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t kt kf =>
          angelic_match_bool <$> persist__term t <*> four kt <*> four kf.

      Definition demonic_match_bool' {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t kt kf.
        apply demonic_binary.
        - eapply bind_right.
          apply assume_formula.
          apply (formula_bool t).
          apply kt.
        - eapply bind_right.
          apply assume_formula.
          apply (formula_bool (term_not t)).
          apply kf.
      Defined.

      Definition demonic_match_bool {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT :=
        fun w0 t kt kf =>
          match term_get_lit t with
          | Some true => T kt
          | Some false => T kf
          | None => demonic_match_bool' t kt kf
          end.

      Definition box_demonic_match_bool {AT} {Γ1 Γ2} :
        ⊢ STerm ty_bool -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t kt kf =>
          demonic_match_bool <$> persist__term t <*> four kt <*> four kf.

      Definition angelic_match_enum {AT E} {Γ1 Γ2} :
        ⊢ STerm (ty_enum E) -> (⌜𝑬𝑲 E⌝ -> □(SMut Γ1 Γ2 AT)) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t cont.
        eapply bind.
        apply (angelic_finite (F := 𝑬𝑲 E)).
        intros δ h.
        apply
            {| msg_function        := "SMut.angelic_match_enum";
               msg_message         := "pattern match assertion";
               msg_program_context := Γ1;
               msg_localstore      := δ;
               msg_heap            := h;
               msg_pathcondition   := wco w0;
            |}.
        intros w1 ω01 EK.
        eapply bind_right.
        apply (assert_formula (formula_eq (subst t ω01) (term_enum E EK))).
        apply (four (cont EK)). auto.
      Defined.

      Definition demonic_match_enum {A E} {Γ1 Γ2} :
        ⊢ STerm (ty_enum E) -> (⌜𝑬𝑲 E⌝ -> □(SMut Γ1 Γ2 A)) -> SMut Γ1 Γ2 A.
      Proof.
        intros w0 t cont.
        eapply bind.
        apply (demonic_finite (F := 𝑬𝑲 E)).
        intros w1 ω01 EK.
        eapply bind_right.
        apply (assume_formula (formula_eq (subst t ω01) (term_enum E EK))).
        apply (four (cont EK)). auto.
      Defined.

      Definition box_demonic_match_enum {AT E} {Γ1 Γ2} :
        ⊢ STerm (ty_enum E) -> (⌜𝑬𝑲 E⌝ -> □(SMut Γ1 Γ2 AT)) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k =>
          demonic_match_enum
            <$> persist__term t
            <*> (fun (w1 : World) (ω01 : w0 ⊒ w1) (EK : 𝑬𝑲 E) => four (k EK) ω01).

      Definition angelic_match_sum {AT Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_sum σ τ) -> □(STerm σ -> SMut Γ1 Γ2 AT) -> □(STerm τ -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t kinl kinr.
        apply angelic_binary.
        - eapply bind.
          apply (angelic (Some x) σ).
          intros w1 ω01 t1.
          eapply bind_right.
          apply assert_formula.
          apply (formula_eq (term_inl t1) (subst t ω01)).
          intros w2 ω12.
          apply (four kinl ω01). auto.
          apply (persist__term t1 ω12).
        - eapply bind.
          apply (angelic (Some y) τ).
          intros w1 ω01 t1.
          eapply bind_right.
          apply assert_formula.
          apply (formula_eq (term_inr t1) (subst t ω01)).
          intros w2 ω12.
          apply (four kinr ω01). auto.
          apply (persist__term t1 ω12).
      Defined.

      Definition demonic_match_sum {AT Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_sum σ τ) -> □(STerm σ -> SMut Γ1 Γ2 AT) -> □(STerm τ -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t kinl kinr.
        apply demonic_binary.
        - eapply bind.
          apply (demonic (Some x) σ).
          intros w1 ω01 t1.
          eapply bind_right.
          apply assume_formula.
          apply (formula_eq (term_inl t1) (subst t ω01)).
          intros w2 ω12.
          apply (four kinl ω01). auto.
          apply (persist__term t1 ω12).
        - eapply bind.
          apply (demonic (Some y) τ).
          intros w1 ω01 t1.
          eapply bind_right.
          apply assume_formula.
          apply (formula_eq (term_inr t1) (subst t ω01)).
          intros w2 ω12.
          apply (four kinr ω01). auto.
          apply (persist__term t1 ω12).
      Defined.

      Definition demonic_match_sum_lifted {AT Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_sum σ τ) -> □(STerm σ -> SMut Γ1 Γ2 AT) -> □(STerm τ -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t kinl kinr POST δ0 h0.
        eapply (SDijk.demonic_match_sum (A := fun w => SStore Γ2 w * SHeap w * AT w)%type x _ y _ _ t).
        - intros w1 ω01 t' POSTl.
          apply kinl. auto. auto.
          intros w2 ω12 a2 δ2 h2.
          apply POSTl. auto. auto.
          apply (subst δ0 ω01).
          apply (subst h0 ω01).
        - intros w1 ω01 t' POSTr.
          apply kinr. auto. auto.
          intros w2 ω12 a2 δ2 h2.
          apply POSTr. auto. auto.
          apply (subst δ0 ω01).
          apply (subst h0 ω01).
        - intros w1 ω01 [[δ1 h1] a1]. apply POST. auto. auto. auto. auto.
      Defined.

      Definition angelic_match_list {AT Γ1 Γ2} (x y : 𝑺) {σ} :
        ⊢ STerm (ty_list σ) -> □(SMut Γ1 Γ2 AT) -> □(STerm σ -> STerm (ty_list σ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t knil kcons.
        apply angelic_binary.
        - eapply bind_right.
          apply assert_formula.
          (* apply *)
          (*   {| msg_function        := "SMut.angelic_match_list"; *)
          (*      msg_message         := "pattern match assertion"; *)
          (*      msg_program_context := Γ1; *)
          (*      msg_localstore      := δ0; *)
          (*      msg_heap            := h0; *)
          (*      msg_pathcondition   := wco w0; *)
          (*   |}. *)
          apply (formula_eq (term_lit (ty_list σ) []) t).
          intros w1 ω01.
          apply knil. auto.
        - eapply bind.
          apply (angelic (Some x) σ).
          intros w1 ω01 thead.
          eapply bind.
          apply (angelic (Some y) (ty_list σ)).
          intros w2 ω12 ttail.
          eapply bind_right.
          apply assert_formula.
          (* apply *)
          (*   {| msg_function        := "SMut.angelic_match_list"; *)
          (*      msg_message         := "pattern match assertion"; *)
          (*      msg_program_context := Γ1; *)
          (*      msg_localstore      := subst δ0 (wtrans ω01 ω12); *)
          (*      msg_heap            := subst h0 (wtrans ω01 ω12); *)
          (*      msg_pathcondition   := wco w2; *)
          (*   |}. *)
          apply (formula_eq (term_binop binop_cons (subst thead ω12) ttail) (subst t (wtrans ω01 ω12))).
          intros w3 ω23.
          apply (four kcons (wtrans ω01 ω12)). auto.
          apply (persist__term thead (wtrans ω12 ω23)).
          apply (persist__term ttail ω23).
      Defined.

      Definition box_angelic_match_list {AT Γ1 Γ2} (x y : 𝑺) {σ} :
        ⊢ STerm (ty_list σ) -> □(SMut Γ1 Γ2 AT) -> □(STerm σ -> STerm (ty_list σ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t knil kcons => angelic_match_list x y <$> persist__term t <*> four knil <*> four kcons.

      Definition demonic_match_list {AT Γ1 Γ2} (x y : 𝑺) {σ} :
        ⊢ STerm (ty_list σ) -> □(SMut Γ1 Γ2 AT) -> □(STerm σ -> STerm (ty_list σ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t knil kcons.
        apply demonic_binary.
        - eapply bind_right.
          apply assume_formula.
          apply (formula_eq (term_lit (ty_list σ) []) t).
          intros w1 ω01.
          apply knil. auto.
        - eapply bind.
          apply (demonic (Some x) σ).
          intros w1 ω01 thead.
          eapply bind.
          apply (demonic (Some y) (ty_list σ)).
          intros w2 ω12 ttail.
          eapply bind_right.
          apply assume_formula.
          apply (formula_eq (term_binop binop_cons (subst thead ω12) ttail) (subst t (wtrans ω01 ω12))).
          intros w3 ω23.
          apply (four kcons (wtrans ω01 ω12)). auto.
          apply (persist__term thead (wtrans ω12 ω23)).
          apply (persist__term ttail ω23).
      Defined.

      Definition box_demonic_match_list {AT Γ1 Γ2} (x y : 𝑺) {σ} :
        ⊢ STerm (ty_list σ) -> □(SMut Γ1 Γ2 AT) -> □(STerm σ -> STerm (ty_list σ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t knil kcons => demonic_match_list x y <$> persist__term t <*> four knil <*> four kcons.

      Definition angelic_match_prod {AT} {Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        apply (bind (angelic (Some x) σ)).
        intros w1 ω01 tσ.
        apply (bind (angelic (Some y) τ)).
        intros w2 ω12 tτ.
        eapply bind_right.
        apply assert_formula.
          (* {| msg_function        := "SMut.angelic_match_prod"; *)
          (*    msg_message         := "pattern match assertion"; *)
          (*    msg_program_context := Γ1; *)
          (*    msg_localstore      := subst δ0 (wtrans ω01 ω12); *)
          (*    msg_heap            := subst h0 (wtrans ω01 ω12); *)
          (*    msg_pathcondition   := wco w2; *)
          (* |}. *)
        apply (formula_eq (term_binop binop_pair (subst tσ ω12) tτ) (subst t (wtrans ω01 ω12))).
        intros w3 ω23.
        apply (four k (wtrans ω01 ω12)). auto.
        apply (persist__term tσ (wtrans ω12 ω23)).
        apply (persist__term tτ ω23).
      Defined.

      Definition box_angelic_match_prod {AT} {Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => angelic_match_prod x y <$> persist__term t <*> four k.

      Definition demonic_match_prod {AT} {Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        apply (bind (demonic (Some x) σ)).
        intros w1 ω01 tσ.
        apply (bind (demonic (Some y) τ)).
        intros w2 ω12 tτ.
        eapply bind_right.
        apply assume_formula.
        apply (formula_eq (term_binop binop_pair (subst tσ ω12) tτ) (subst t (wtrans ω01 ω12))).
        intros w3 ω23.
        apply (four k (wtrans ω01 ω12)). auto.
        apply (persist__term tσ (wtrans ω12 ω23)).
        apply (persist__term tτ ω23).
      Defined.

      Definition box_demonic_match_prod {AT} {Γ1 Γ2} (x y : 𝑺) {σ τ} :
        ⊢ STerm (ty_prod σ τ) -> □(STerm σ -> STerm τ -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => demonic_match_prod x y <$> persist__term t <*> four k.

      Definition angelic_match_record' {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        eapply bind.
        apply (angelic_ctx n Δ).
        intros w1 ω01 ts.
        eapply bind_right.
        apply assert_formula.
          (* {| msg_function        := "SMut.angelic_match_record"; *)
          (*    msg_message         := "pattern match assertion"; *)
          (*    msg_program_context := Γ1; *)
          (*    msg_localstore      := subst δ0 (wtrans ω01 ω12); *)
          (*    msg_heap            := subst h0 (wtrans ω01 ω12); *)
          (*    msg_pathcondition   := wco w2; *)
          (* |}. *)
        apply (formula_eq (term_record R (record_pattern_match_env_reverse p ts)) (subst t ω01)).
        intros w2 ω12.
        apply (four k ω01). auto.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts (wsub ω12)).
      Defined.

      Definition angelic_match_record {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        destruct (term_get_record t).
        - apply (T k).
          apply (record_pattern_match_env p n0).
        - apply (angelic_match_record' n p t k).
      Defined.

      Definition box_angelic_match_record {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => angelic_match_record n p <$> persist__term t <*> four k.

      Definition demonic_match_record' {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        eapply bind.
        apply (demonic_ctx n Δ).
        intros w1 ω01 ts.
        eapply bind_right.
        apply assume_formula.
        apply (formula_eq (term_record R (record_pattern_match_env_reverse p ts)) (subst t ω01)).
        intros w2 ω12.
        apply (four k ω01). auto.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts (wsub ω12)).
      Defined.

      Definition demonic_match_record {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        destruct (term_get_record t).
        - apply (T k).
          apply (record_pattern_match_env p n0).
        - apply (demonic_match_record' n p t k).
      Defined.

      Definition box_demonic_match_record {N : Set} (n : N -> 𝑺) {AT R Γ1 Γ2} {Δ : NCtx N Ty} (p : RecordPat (𝑹𝑭_Ty R) Δ) :
        ⊢ STerm (ty_record R) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => demonic_match_record n p <$> persist__term t <*> four k.

      Definition angelic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs Γ1 Γ2} {Δ : NCtx N Ty} (p : TuplePat σs Δ) :
        ⊢ STerm (ty_tuple σs) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        eapply bind.
        apply (angelic_ctx n Δ).
        intros w1 ω01 ts.
        eapply bind_right.
        apply assert_formula.
          (* {| msg_function        := "SMut.angelic_match_tuple"; *)
          (*    msg_message         := "pattern match assertion"; *)
          (*    msg_program_context := Γ1; *)
          (*    msg_localstore      := subst δ0 (wtrans ω01 ω12); *)
          (*    msg_heap            := subst h0 (wtrans ω01 ω12); *)
          (*    msg_pathcondition   := wco w2; *)
        (* |}. *)
        apply (formula_eq (term_tuple (tuple_pattern_match_env_reverse p ts)) (subst t ω01)).
        intros w2 ω12.
        apply (four k ω01). auto.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts (wsub ω12)).
      Defined.

      Definition box_angelic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs Γ1 Γ2} {Δ : NCtx N Ty} (p : TuplePat σs Δ) :
        ⊢ STerm (ty_tuple σs) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => angelic_match_tuple n p <$> persist__term t <*> four k.

      Definition demonic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs Γ1 Γ2} {Δ : NCtx N Ty} (p : TuplePat σs Δ) :
        ⊢ STerm (ty_tuple σs) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t k.
        eapply bind.
        apply (demonic_ctx n Δ).
        intros w1 ω01 ts.
        eapply bind_right.
        apply assume_formula.
        apply (formula_eq (term_tuple (tuple_pattern_match_env_reverse p ts)) (subst t ω01)).
        intros w2 ω12.
        apply (four k ω01). auto.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts (wsub ω12)).
      Defined.

      Definition box_demonic_match_tuple {N : Set} (n : N -> 𝑺) {AT σs Γ1 Γ2} {Δ : NCtx N Ty} (p : TuplePat σs Δ) :
        ⊢ STerm (ty_tuple σs) -> □((fun w => NamedEnv (Term w) Δ) -> SMut Γ1 Γ2 AT) -> □(SMut Γ1 Γ2 AT) :=
        fun w0 t k => demonic_match_tuple n p <$> persist__term t <*> four k.

      Definition angelic_match_pattern {N : Set} (n : N -> 𝑺) {σ} {Δ : NCtx N Ty} (p : Pattern Δ σ) {Γ} :
        ⊢ (SStore Γ -> SHeap -> Message) -> STerm σ -> SMut Γ Γ (fun w => NamedEnv (Term w) Δ).
      Proof.
        intros w0 msg t.
        eapply (bind).
        apply (angelic_ctx n Δ).
        intros w1 ω01 ts.
        eapply (bind_right).
        apply assert_formula.
        apply (formula_eq (pattern_match_env_reverse p ts) (subst t ω01)).
        intros w2 ω12.
        apply pure.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts ω12).
      Defined.

      Definition demonic_match_pattern {N : Set} (n : N -> 𝑺) {σ} {Δ : NCtx N Ty} (p : Pattern Δ σ) {Γ} :
        ⊢ STerm σ -> SMut Γ Γ (fun w => NamedEnv (Term w) Δ).
      Proof.
        intros w0 t.
        eapply (bind).
        apply (demonic_ctx n Δ).
        intros w1 ω01 ts.
        eapply (bind_right).
        apply assume_formula.
        apply (formula_eq (pattern_match_env_reverse p ts) (subst t ω01)).
        intros w2 ω12.
        apply pure.
        apply (subst (T := fun Σ => NamedEnv (Term Σ) Δ) ts ω12).
      Defined.

      Definition angelic_match_union {N : Set} (n : N -> 𝑺) {AT Γ1 Γ2 U}
        {Δ : 𝑼𝑲 U -> NCtx N Ty} (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) :
        ⊢ STerm (ty_union U) -> (∀ K, □((fun w => NamedEnv (Term w) (Δ K)) -> SMut Γ1 Γ2 AT)) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t cont.
        eapply bind.
        apply (angelic_finite (F := 𝑼𝑲 U)).
        intros δ h.
        apply
            {| msg_function        := "SMut.angelic_match_union";
               msg_message         := "pattern match assertion";
               msg_program_context := Γ1;
               msg_localstore      := δ;
               msg_heap            := h;
               msg_pathcondition   := wco w0;
            |}.
        intros w1 ω01 UK.
        eapply bind.
        apply (angelic None (𝑼𝑲_Ty UK)).
        intros w2 ω12 t__field.
        eapply bind_right.
        apply assert_formula.
        apply (formula_eq (term_union U UK t__field) (persist__term t (wtrans ω01 ω12))).
        intros w3 ω23.
        eapply bind.
        apply (angelic_match_pattern n (p UK)).
        intros δ h.
        apply
            {| msg_function        := "SMut.angelic_match_union";
               msg_message         := "pattern match assertion";
               msg_program_context := Γ1;
               msg_localstore      := δ;
               msg_heap            := h;
               msg_pathcondition   := wco w3;
            |}.
        apply (persist__term t__field ω23).
        apply (four (cont UK)).
        apply (wtrans ω01 (wtrans ω12 ω23)).
      Defined.

      Definition box_angelic_match_union {N : Set} (n : N -> 𝑺) {AT Γ1 Γ2 U}
        {Δ : 𝑼𝑲 U -> NCtx N Ty} (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) :
        ⊢ STerm (ty_union U) -> (∀ K, □((fun w => NamedEnv (Term w) (Δ K)) -> SMut Γ1 Γ2 AT)) -> □(SMut Γ1 Γ2 AT).
      Proof.
        refine (fun w0 t k => angelic_match_union n p <$> persist__term t <*> _).
        intros w1 ω01 UK. apply (four (k UK) ω01).
      Defined.

      Definition demonic_match_union {N : Set} (n : N -> 𝑺) {AT Γ1 Γ2 U}
        {Δ : 𝑼𝑲 U -> NCtx N Ty} (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) :
        ⊢ STerm (ty_union U) -> (∀ K, □((fun w => NamedEnv (Term w) (Δ K)) -> SMut Γ1 Γ2 AT)) -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t cont.
        eapply bind.
        apply (demonic_finite (F := 𝑼𝑲 U)).
        intros w1 ω01 UK.
        eapply bind.
        apply (demonic None (𝑼𝑲_Ty UK)).
        intros w2 ω12 t__field.
        eapply bind_right.
        apply assume_formula.
        apply (formula_eq (term_union U UK t__field) (persist__term t (wtrans ω01 ω12))).
        intros w3 ω23.
        eapply bind.
        apply (demonic_match_pattern n (p UK)).
        apply (persist__term t__field ω23).
        apply (four (cont UK)).
        apply (wtrans ω01 (wtrans ω12 ω23)).
      Defined.

      Definition box_demonic_match_union {N : Set} (n : N -> 𝑺) {AT Γ1 Γ2 U}
        {Δ : 𝑼𝑲 U -> NCtx N Ty} (p : forall K : 𝑼𝑲 U, Pattern (Δ K) (𝑼𝑲_Ty K)) :
        ⊢ STerm (ty_union U) -> (∀ K, □((fun w => NamedEnv (Term w) (Δ K)) -> SMut Γ1 Γ2 AT)) -> □(SMut Γ1 Γ2 AT).
      Proof.
        refine (fun w0 t k => demonic_match_union n p <$> persist__term t <*> _).
        intros w1 ω01 UK. apply (four (k UK) ω01).
      Defined.

    End PatternMatching.

    Section State.

      Definition pushpop {AT Γ1 Γ2 x σ} :
        ⊢ STerm σ -> SMut (Γ1 ▻ (x :: σ)) (Γ2 ▻ (x :: σ)) AT -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 t m POST δ h.
        apply m.
        intros w1 ω01 a1 δ1 h1.
        apply POST. auto. auto. apply (env_tail δ1). apply h1.
        apply env_snoc.
        apply δ.
        apply t.
        apply h.
      Defined.

      Definition pushspops {AT Γ1 Γ2 Δ} :
        ⊢ SStore Δ -> SMut (Γ1 ▻▻ Δ) (Γ2 ▻▻ Δ) AT -> SMut Γ1 Γ2 AT.
      Proof.
        intros w0 δΔ m POST δ h.
        apply m.
        intros w1 ω01 a1 δ1 h1.
        apply POST. auto. auto. apply (env_drop Δ δ1). apply h1.
        apply env_cat.
        apply δ.
        apply δΔ.
        apply h.
      Defined.

      Definition get_local {Γ} : ⊢ SMut Γ Γ (SStore Γ) :=
        fun w0 POST δ => T POST δ δ.
      Definition put_local {Γ1 Γ2} : ⊢ SStore Γ2 -> SMut Γ1 Γ2 Unit :=
        fun w0 δ POST _ => T POST tt δ.
      Definition get_heap {Γ} : ⊢ SMut Γ Γ SHeap :=
        fun w0 POST δ h => T POST h δ h.
      Definition put_heap {Γ} : ⊢ SHeap -> SMut Γ Γ Unit :=
        fun w0 h POST δ _ => T POST tt δ h.

      Definition eval_exp {Γ σ} (e : Exp Γ σ) :
        ⊢ SMut Γ Γ (STerm σ).
        intros w POST δ h.
        apply POST.
        apply wrefl.
        apply (seval_exp δ e).
        auto.
        auto.
      Defined.

      Definition eval_exps {Γ} {σs : PCtx} (es : NamedEnv (Exp Γ) σs) :
        ⊢ SMut Γ Γ (SStore σs).
        intros w POST δ h.
        apply POST. apply wrefl.
        refine (env_map _ es).
        intros b. apply (seval_exp δ).
        auto.
        auto.
      Defined.

      Definition assign {Γ} x {σ} {xIn : x::σ ∈ Γ} : ⊢ STerm σ -> SMut Γ Γ Unit :=
        fun w0 t POST δ => T POST tt (δ ⟪ x ↦ t ⟫).
      Global Arguments assign {Γ} x {σ xIn w} v.

    End State.

    Section ProduceConsume.

      Definition produce_chunk {Γ} :
        ⊢ Chunk -> SMut Γ Γ Unit.
      Proof.
        intros w0 c k δ h.
        apply k. apply wrefl.
        constructor. apply δ.
        apply (cons c h).
      Defined.

      Fixpoint try_consume_chunk_exact {Σ} (h : SHeap Σ) (c : Chunk Σ) {struct h} : option (SHeap Σ) :=
        match h with
        | nil       => None
        | cons c' h =>
          if chunk_eqb c c'
          then Some h
          else option_map (cons c') (try_consume_chunk_exact h c)
        end.

      Equations(noeqns) match_chunk {w : World} (c1 c2 : Chunk w) : List Formula w :=
        match_chunk (chunk_user p1 vs1) (chunk_user p2 vs2)
        with eq_dec p1 p2 => {
          match_chunk (chunk_user p1 vs1) (chunk_user p2 vs2) (left eq_refl) := formula_eqs_ctx vs1 vs2;
          match_chunk (chunk_user p1 vs1) (chunk_user p2 vs2) (right _) :=
            cons (formula_bool (term_lit ty_bool false)) nil
        };
        match_chunk (chunk_ptsreg r1 t1) (chunk_ptsreg r2 t2)
        with eq_dec_het r1 r2 => {
          match_chunk (chunk_ptsreg r1 v1) (chunk_ptsreg r2 v2) (left eq_refl) := cons (formula_eq v1 v2) nil;
          match_chunk (chunk_ptsreg r1 v1) (chunk_ptsreg r2 v2) (right _)      :=
            cons (formula_bool (term_lit ty_bool false)) nil
        };
        match_chunk _ _  := cons (formula_bool (term_lit ty_bool false)) nil.

      Lemma inst_match_chunk {w : World} (c1 c2 : Chunk w) (ι : SymInstance w) :
        instpc (match_chunk c1 c2) ι <-> inst c1 ι = inst c2 ι.
      Proof.
        split.
        - destruct c1, c2; cbn.
          + destruct (eq_dec p p0).
            * destruct e; cbn.
              rewrite inst_formula_eqs_ctx.
              intuition.
            * intros HYP; cbv in HYP. discriminate.
          + intros HYP; cbv in HYP. discriminate.
          + intros HYP; cbv in HYP. discriminate.
          + destruct (eq_dec_het r r0).
            * dependent elimination e; cbn.
              rewrite inst_pathcondition_cons.
              now intros [-> _].
            * intros HYP; cbv in HYP. discriminate.
        - destruct c1, c2; cbn; intros Heq.
          + remember (inst ts ι) as vs1.
            remember (inst ts0 ι) as vs2.
            dependent elimination Heq.
            rewrite EqDec.eq_dec_refl. cbn.
            rewrite inst_formula_eqs_ctx.
            subst. auto.
          + dependent elimination Heq.
          + dependent elimination Heq.
          + remember (inst t ι) as v1.
            remember (inst t0 ι) as v2.
            dependent elimination Heq.
            unfold eq_dec_het.
            rewrite EqDec.eq_dec_refl. cbn.
            rewrite inst_pathcondition_cons.
            subst. split; auto. constructor.
      Qed.

      Definition consume_chunk {Γ} :
        ⊢ Chunk -> SMut Γ Γ Unit.
      Proof.
        intros w0 c.
        eapply bind.
        apply get_heap.
        intros w1 ω01 h.
        destruct (try_consume_chunk_exact h (subst c ω01)) as [h'|].
        - apply put_heap.
          apply h'.
        - eapply bind.
          apply (angelic_list
                   (A := Pair Chunk SHeap)
                   (fun δ h =>
                      {| msg_function := "consume_chunk";
                         msg_message := "Empty extraction";
                         msg_program_context := Γ;
                         msg_localstore := δ;
                         msg_heap := h;
                         msg_pathcondition := wco w1
                      |})
                   (heap_extractions h)).
          intros w2 ω12 [c' h'].
          eapply bind_right.
          apply assert_formulas.
          apply (match_chunk (subst c (wtrans ω01 ω12)) c').
          intros w3 ω23.
          apply put_heap.
          apply (subst h' ω23).
      Defined.

      (* Definition smut_leakcheck {Γ Σ} : SMut Γ Γ Unit Σ := *)
      (*   smut_get_heap >>= fun _ _ h => *)
      (*   match h with *)
      (*   | nil => smut_pure tt *)
      (*   | _   => smut_error "SMut.leakcheck" "Heap leak" h *)
      (*   end. *)

      Definition produce_fail_recursion {Γ} :
        ⊢ Assertion -> SMut Γ Γ Unit.
      Proof.
        refine
          (fix produce w0 asn {struct asn} :=
             match asn with
             | asn_sep asn1 asn2 =>
               bind_right
                 (produce w0 asn1)
                 (* Recursive call to produce has principal argument equal to "persist asn2 ω01" *)
                 (* instead of one of the following variables: "asn1" "asn2". *)
                 (produce <$> persist asn2)
             | _ => @block _ _ _ _
             end).
      Abort.

      Definition produce {Γ} :
        ⊢ Assertion -> □(SMut Γ Γ Unit).
      Proof.
        refine (fix produce w0 asn {struct asn} := _).
        destruct asn.
        - apply (box_assume_formula fml).
        - apply (produce_chunk <$> persist c).
        - apply (demonic_match_bool <$> persist__term b <*> four (produce _ asn1) <*> four (produce _ asn2)).
        - intros w1 ω01.
          apply (demonic_match_enum
                    (persist__term k ω01)
                    (fun EK : 𝑬𝑲 E => four (produce w0 (alts EK)) ω01)).
        - refine (demonic_match_sum (AT := Unit) (Γ1 := Γ) (Γ2 := Γ) xl xr <$> persist__term s <*> four _ <*> four _).
          intros w1 ω01 t1.
          apply (produce (wsnoc w0 (xl :: σ)) asn1).
          apply (wsnoc_sub ω01 (xl :: σ) t1).
          intros w1 ω01 t1.
          apply (produce (wsnoc w0 (xr :: τ)) asn2).
          apply (wsnoc_sub ω01 (xr :: τ) t1).
        - apply (box_demonic_match_list xh xt s).
          + apply (produce _ asn1).
          + intros w1 ω01 thead ttail.
            apply (produce (wsnoc (wsnoc w0 (xh :: _)) (xt :: _)) asn2 w1).
            apply (wsnoc_sub (wsnoc_sub ω01 (xh :: _) thead) (xt :: _) ttail).
        - apply (box_demonic_match_prod xl xr s).
          intros w1 ω01 t1 t2.
          apply (produce (wsnoc (wsnoc w0 (xl :: σ1)) (xr :: σ2)) asn w1).
          apply (wsnoc_sub (wsnoc_sub ω01 (xl :: σ1) t1) (xr :: σ2) t2).
        - apply (box_demonic_match_tuple id p s).
          intros w1 ω01 ts.
          apply (produce (wcat w0 Δ) asn w1).
          apply wcat_sub; auto.
        - apply (box_demonic_match_record id p s).
          intros w1 ω01 ts.
          apply (produce (wcat w0 Δ) asn w1).
          apply wcat_sub; auto.
        - apply (box_demonic_match_union id alt__pat s).
          intros UK w1 ω01 ts.
          apply (produce (wcat w0 (alt__ctx UK)) (alt__rhs UK) w1).
          apply wcat_sub; auto.
        - apply (bind_right <$> produce _ asn1 <*> four (produce _ asn2)).
        - intros w1 ω01.
          eapply bind.
          apply (@demonic _ (Some ς) τ).
          intros w2 ω12 t2.
          apply (produce (wsnoc w0 (ς :: τ)) asn w2).
          apply (wsnoc_sub (wtrans ω01 ω12) (ς :: τ) t2).
        - intros w1 ω01.
          apply debug.
          intros δ h.
          apply (MkSDebugAsn (wco w1) δ h).
          apply pure.
          constructor.
      Defined.

      Definition consume {Γ} :
        ⊢ Assertion -> □(SMut Γ Γ Unit).
      Proof.
        refine (fix consume w0 asn {struct asn} := _).
        destruct asn.
        - apply (box_assert_formula fml).
        - apply (consume_chunk <$> persist c).
        - apply (angelic_match_bool <$> persist__term b <*> four (consume _ asn1) <*> four (consume _ asn2)).
        - intros w1 ω01.
          apply (angelic_match_enum
                    (persist__term k ω01)
                    (fun EK : 𝑬𝑲 E => four (consume w0 (alts EK)) ω01)).
        - refine (angelic_match_sum (AT := Unit) (Γ1 := Γ) (Γ2 := Γ) xl xr <$> persist__term s <*> four _ <*> four _).
          intros w1 ω01 t1.
          apply (consume (wsnoc w0 (xl :: σ)) asn1).
          apply (wsnoc_sub ω01 (xl :: σ) t1).
          intros w1 ω01 t1.
          apply (consume (wsnoc w0 (xr :: τ)) asn2).
          apply (wsnoc_sub ω01 (xr :: τ) t1).
        - apply (box_angelic_match_list xh xt s).
          + apply (consume _ asn1).
          + intros w1 ω01 thead ttail.
            apply (consume (wsnoc (wsnoc w0 (xh :: _)) (xt :: _)) asn2 w1).
            apply (wsnoc_sub (wsnoc_sub ω01 (xh :: _) thead) (xt :: _) ttail).
        - apply (box_angelic_match_prod xl xr s).
          intros w1 ω01 t1 t2.
          apply (consume (wsnoc (wsnoc w0 (xl :: σ1)) (xr :: σ2)) asn w1).
          apply (wsnoc_sub (wsnoc_sub ω01 (xl :: σ1) t1) (xr :: σ2) t2).
        - apply (box_angelic_match_tuple id p s).
          intros w1 ω01 ts.
          apply (consume (wcat w0 Δ) asn w1).
          apply wcat_sub; auto.
        - apply (box_angelic_match_record id p s).
          intros w1 ω01 ts.
          apply (consume (wcat w0 Δ) asn w1).
          apply wcat_sub; auto.
        - apply (box_angelic_match_union id alt__pat s).
          intros UK w1 ω01 ts.
          apply (consume (wcat w0 (alt__ctx UK)) (alt__rhs UK) w1).
          apply wcat_sub; auto.
        - apply (bind_right <$> consume _ asn1 <*> four (consume _ asn2)).
        - intros w1 ω01.
          eapply bind.
          apply (@angelic _ (Some ς) τ).
          intros w2 ω12 t2.
          apply (consume (wsnoc w0 (ς :: τ)) asn w2).
          apply (wsnoc_sub (wtrans ω01 ω12) (ς :: τ) t2).
        - intros w1 ω01.
          apply debug.
          intros δ h.
          apply (MkSDebugAsn (wco w1) δ h).
          apply pure.
          constructor.
      Defined.

    End ProduceConsume.

    Section Exec.

      Variable cfg : Config.

      Definition call_contract {Γ Δ τ} (c : SepContract Δ τ) :
        ⊢ SStore Δ -> SMut Γ Γ (STerm τ).
      Proof.
        refine
          (match c with
           | MkSepContract _ _ Σe δe req result ens => _
           end).
        intros w0 args.
        eapply bind.
        apply (angelic_ctx id Σe).
        intros w1 ω01 evars.
        eapply bind_right.
        apply (assert_formulas
                 (* {| *)
                 (*   msg_function := "SMut.call"; *)
                 (*   msg_message := "argument pattern match"; *)
                 (*   msg_program_context := Γ; *)
                 (*   msg_localstore := subst δ0 ω01; *)
                 (*   msg_heap := subst h0 ω01; *)
                 (*   msg_pathcondition := wco w1; *)
                 (* |} *) (formula_eqs_nctx (subst δe evars) (subst args ω01))).
        intros w2 ω12.
        eapply bind_right.
        apply (consume (w := @MkWorld Σe nil) req).
        refine (wtrans _ ω12).
        constructor 1 with evars. cbn. constructor.
        intros w3 ω23.
        eapply bind.
        apply (demonic (Some result)).
        intros w4 ω34 res.
        eapply bind_right.
        apply (produce
                 (w := @MkWorld (Σe ▻ (result::τ)) nil)
                 ens).
        constructor 1 with (sub_snoc (subst (T := Sub _) evars (wtrans ω12 (wtrans ω23 ω34))) (result::τ) res).
        cbn. constructor.
        intros w5 ω45. clear - res ω45.
        apply pure.
        apply (persist__term res ω45).
      Defined.

      Definition call_contract_debug {Γ Δ τ} (f : 𝑭 Δ τ) (c : SepContract Δ τ) :
        ⊢ SStore Δ -> SMut Γ Γ (STerm τ) :=
        fun w0 δΔ =>
          let o := call_contract c δΔ in
          if config_debug_function cfg f
          then
            debug
              (fun δ h => {| sdebug_call_function_parameters := Δ;
                             sdebug_call_function_result_type := τ;
                             sdebug_call_function_name := f;
                             sdebug_call_function_contract := c;
                             sdebug_call_function_arguments := δΔ;
                             sdebug_call_program_context := Γ;
                             sdebug_call_pathcondition := wco w0;
                             sdebug_call_localstore := δ;
                             sdebug_call_heap := h|})
              o
          else o.

      Fixpoint exec {Γ τ} (s : Stm Γ τ) {struct s} :
        ⊢ SMut Γ Γ (STerm τ).
      Proof.
        intros w0; destruct s.
        - apply pure. apply (term_lit τ l).
        - apply (eval_exp e).
        - eapply bind. apply (exec _ _ s1).
          intros w1 ω01 t1.
          eapply (pushpop t1).
          apply (exec _ _ s2).
        - eapply (pushspops (lift δ)).
          apply (exec _ _ s).
        - eapply bind.
          apply (exec _ _ s).
          intros w1 ω01 t.
          eapply bind_right.
          apply (assign x t).
          intros w2 ω12.
          apply pure.
          apply (subst (T := STerm τ) t (wsub ω12)).
        - eapply bind.
          apply (eval_exps es).
          intros w1 ω01 args.
          destruct (CEnv f) as [c|].
          + apply (call_contract_debug f c args).
          + apply (error "SMut.exec" "Function call without contract" (f,args)).
        - rename δ into δΔ.
          eapply bind.
          apply get_local.
          intros w1 ω01 δ1.
          eapply bind_right.
          apply (put_local (lift δΔ)).
          intros w2 ω12.
          eapply bind.
          apply (exec _ _ s).
          intros w3 ω23 t.
          eapply bind_right.
          apply put_local.
          apply (subst δ1 (wtrans ω12 ω23)).
          intros w4 ω34.
          apply pure.
          apply (subst (T := STerm _) t ω34).
        - eapply bind.
          apply (eval_exps es).
          intros w1 ω01 args.
          apply (call_contract (CEnvEx f) args).
        - eapply bind. apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_bool t).
          + intros w2 ω12.
            apply (exec _ _ s1).
          + intros w2 ω12.
            apply (exec _ _ s2).
        - eapply bind_right.
          apply (exec _ _ s1).
          intros w1 ω01.
          apply (exec _ _ s2).
        - eapply bind. apply (eval_exp e1).
          intros w1 ω01 t.
          eapply bind_right.
          apply (assume_formula (formula_bool t)).
          intros w2 ω12.
          apply (exec _ _ s).
        - apply block.
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_list (𝑿to𝑺 xh) (𝑿to𝑺 xt) t).
          + intros w2 ω12.
            apply (exec _ _ s1).
          + intros w2 ω12 thead ttail.
            eapply (pushspops (env_snoc (env_snoc env_nil (xh,_) thead) (xt,_) ttail)).
            apply (exec _ _ s2).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_sum (𝑿to𝑺 xinl) (𝑿to𝑺 xinr) t).
          + intros w2 ω12 tl.
            eapply (pushpop tl).
            apply (exec _ _ s1).
          + intros w2 ω12 tr.
            eapply (pushpop tr).
            apply (exec _ _ s2).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_prod (𝑿to𝑺 xl) (𝑿to𝑺 xr) t).
          intros w2 ω12 t1 t2.
          eapply (pushspops (env_snoc (env_snoc env_nil (_,_) t1) (_,_) t2)).
          apply (exec _ _ s).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_enum t).
          intros EK.
          intros w2 ω12.
          apply (exec _ _ (alts EK)).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_tuple 𝑿to𝑺 p t).
          intros w2 ω12 ts.
          eapply (pushspops ts).
          apply (exec _ _ s).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_union 𝑿to𝑺 alt__pat t).
          intros UK w2 ω12 ts.
          eapply (pushspops ts).
          apply (exec _ _ (alt__rhs UK)).
        - eapply bind.
          apply (eval_exp e).
          intros w1 ω01 t.
          apply (demonic_match_record 𝑿to𝑺 p t).
          intros w2 ω12 ts.
          eapply (pushspops ts).
          apply (exec _ _ s).
        - eapply bind.
          apply (angelic None τ).
          intros w1 ω01 t.
          eapply bind_right.
          apply (T (consume (asn_chunk (chunk_ptsreg reg t)))).
          intros w2 ω12.
          eapply bind_right.
          apply (T (produce (asn_chunk (chunk_ptsreg reg (subst t ω12))))).
          intros w3 ω23.
          apply pure.
          apply (subst (T := STerm _) t (wtrans ω12 ω23)).
        - eapply bind.
          eapply (angelic None τ).
          intros w1 ω01 told.
          eapply bind_right.
          apply (T (consume (asn_chunk (chunk_ptsreg reg told)))).
          intros w2 ω12.
          eapply bind.
          apply (eval_exp e).
          intros w3 ω23 tnew.
          eapply bind_right.
          apply (T (produce (asn_chunk (chunk_ptsreg reg tnew)))).
          intros w4 ω34.
          apply pure.
          apply (subst (T := STerm _) tnew ω34).
        - apply (error "SMut.exec" "stm_bind not supported" tt).
        - apply debug.
          intros δ0 h0.
          econstructor.
          apply (wco w0).
          apply δ0.
          apply h0.
          apply (exec _ _ s).
      Defined.
      Global Arguments exec {_ _} _ {w} _ _ _.

      Import Notations.

      Definition exec_contract {Δ τ} (c : SepContract Δ τ) (s : Stm Δ τ) :
        SMut Δ Δ Unit {| wctx := sep_contract_logic_variables c; wco := [] |} :=
        match c with
        | MkSepContract _ _ Σ δ req result ens =>
          produce (w:=@MkWorld _ _) req wrefl >> fun w1 ω01 =>
          exec s >>= fun w2 ω12 res =>
          consume
            (w:=wsnoc (@MkWorld _ []) (result :: τ))
            ens
            (wsnoc_sub (wtrans ω01 ω12) (result :: τ) res)
        end.

      Definition exec_contract_path {Δ : PCtx} {τ : Ty} (c : SepContract Δ τ) (s : Stm Δ τ) : SPath wnil :=
        demonic_close (exec_contract c s (fun w1 ω01 _ δ1 h1 => SPath.block) (sep_contract_localstore c) nil).

      Definition ValidContractWithConfig {Δ τ} (c : SepContract Δ τ) (body : Stm Δ τ) : Prop :=
        VerificationCondition (prune (Experimental.solve_evars ctx_nil (prune (exec_contract_path c body)) nil)).

    End Exec.

    Definition ValidContract {Δ τ} (c : SepContract Δ τ) (body : Stm Δ τ) : Prop :=
      VerificationCondition (prune (Experimental.solve_evars ctx_nil (prune (exec_contract_path default_config c body)) nil)).

    Definition ValidContractReflect {Δ τ} (c : SepContract Δ τ) (body : Stm Δ τ) : Prop :=
      is_true (ok (prune (Experimental.solve_evars ctx_nil (prune (exec_contract_path default_config c body)) nil))).

    Lemma validcontract_reflect_sound {Δ τ} (c : SepContract Δ τ) (body : Stm Δ τ) :
      ValidContractReflect c body ->
      ValidContract c body.
    Proof.
      unfold ValidContractReflect, ValidContract. intros Hok.
      apply (ok_sound _ env_nil) in Hok. now constructor.
    Qed.

  End SMut.

End Mutators.

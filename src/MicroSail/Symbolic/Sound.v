(******************************************************************************)
(* Copyright (c) 2019 Steven Keuchel                                          *)
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
     Bool.Bool
     Program.Equality
     Program.Tactics
     ZArith.ZArith
     Strings.String
     Classes.Morphisms
     Classes.Morphisms_Prop
     Classes.Morphisms_Relations.

From Equations Require Import
     Equations.

From MicroSail Require Import
     Sep.Spec
     Sep.Logic
     Sep.Hoare
     Syntax
     Tactics
     Symbolic.Mutator.
From MicroSail Require Import
     SemiConcrete.Mutator
     SemiConcrete.Outcome
     SemiConcrete.Sound.

Set Implicit Arguments.

Import CtxNotations.
Import EnvNotations.

Module Soundness
       (Import termkit : TermKit)
       (Import progkit : ProgramKit termkit)
       (Import assertkit : AssertionKit termkit progkit)
       (Import contractkit : SymbolicContractKit termkit progkit assertkit).
  Module MUT := Mutators termkit progkit assertkit contractkit.
  Import MUT.
  Module LOG := ProgramLogic termkit progkit assertkit contractkit.
  Import LOG.
  Module SCMUT := SemiConcrete.Sound.Soundness termkit progkit assertkit contractkit.
  Import SCMUT.MUT.

  Module DynMutV1Soundness.

    Import DynMutV1.

    Global Instance inst_heap : Inst SymbolicHeap SCHeap :=
      instantiate_list.
    Global Instance instlaws_heap : InstLaws SymbolicHeap SCHeap.
    Proof. apply instantiatelaws_list. Qed.

    (* Relate two symbolic instances at different points during execution. This
       essentially encodes a preorder on the total space { Σ & SymInstance Σ },
       which encodes that ι2 is a future of ι1, i.e. it is derived by compatible
       for existing variables and values for new universal variables. *)
    Definition syminstance_rel {Σ1 Σ2} (ζ : Sub Σ1 Σ2) (ι1 : SymInstance Σ1) (ι2 : SymInstance Σ2) : Prop :=
      inst ι2 ζ = ι1.
    Hint Unfold syminstance_rel : core.

    Lemma syminstance_rel_refl {Σ} (ι : SymInstance Σ) :
      syminstance_rel (sub_id Σ) ι ι.
    Proof. apply inst_sub_id. Qed.

    Lemma syminstance_rel_refl_inv {Σ} (ι1 ι2 : SymInstance Σ) :
      syminstance_rel (sub_id Σ) ι1 ι2 -> ι2 = ι1.
    Proof. unfold syminstance_rel. now rewrite inst_sub_id. Qed.

    Lemma syminstance_rel_snoc {Σ1 Σ2 x τ} (ζ : Sub Σ1 Σ2) (ι1 : SymInstance Σ1) ι2 :
      forall t v,
        syminstance_rel (env_snoc ζ (x,τ) t) (env_snoc ι1 (x,τ) v) ι2 <->
        syminstance_rel ζ ι1 ι2 /\ v = inst ι2 t.
    Proof.
      unfold syminstance_rel. intros. split.
      - cbn; intros.
        now dependent elimination H.
      - cbn; intros []; subst; now cbn.
    Qed.

    Lemma syminstance_rel_comp {Σ0 Σ1 Σ2} (ζ1 : Sub Σ0 Σ1) (ζ2 : Sub Σ1 Σ2)
          (ι0 : SymInstance Σ0) (ι2 : SymInstance Σ2):
      syminstance_rel (sub_comp ζ1 ζ2) ι0 ι2 <->
      syminstance_rel ζ1 ι0 (inst ι2 ζ2).
    Proof. unfold syminstance_rel. now rewrite <- inst_subst. Qed.

    Lemma syminstance_rel_trans {Σ0 Σ1 Σ2} {ζ1 : Sub Σ0 Σ1} {ζ2 : Sub Σ1 Σ2}
          {ι0 : SymInstance Σ0} {ι1 : SymInstance Σ1} {ι2 : SymInstance Σ2} :
      syminstance_rel ζ1 ι0 ι1 -> syminstance_rel ζ2 ι1 ι2 ->
      syminstance_rel (sub_comp ζ1 ζ2) ι0 ι2.
    Proof. intros. apply syminstance_rel_comp. congruence. Qed.

    Lemma syminstance_rel_wk1 {Σ : NCtx 𝑺 Ty} {x τ} (ι : SymInstance Σ) (v : Lit τ) :
      syminstance_rel sub_wk1 ι (ι ► ((x, τ) ↦ v)).
    Proof. apply inst_sub_wk1. Qed.

    Lemma syminstance_rel_up {Σ1 Σ2 x τ} (ζ : Sub Σ1 Σ2) (ι1 : SymInstance Σ1) ι2 :
      forall v,
        syminstance_rel (sub_up1 ζ) (env_snoc ι1 (x,τ) v) (env_snoc ι2 (x,τ) v) <->
        syminstance_rel ζ ι1 ι2.
    Proof.
      unfold syminstance_rel. intros v.
      change (inst (ι2 ► (x :: τ ↦ v)) (sub_comp ζ sub_wk1) ► (x :: τ ↦ v) =
              ι1 ► (x :: τ ↦ v) <-> inst ι2 ζ = ι1).
      unfold sub_comp. rewrite inst_subst, inst_sub_wk1.
      split; intros H.
      - now dependent elimination H.
      - now f_equal.
    Qed.

    (* A relation that links semi-concrete states with symbolic states. This
       simply requires that when instantiating the symbolic state you get the
       semi-concrete one (and the path-condition is true). Note that the
       equality used in the heap instantiation requires the symbolic and the
       semi-concrete executor to be in lock step with respect to the heap: i.e.
       the symbolic executor and the semi-concrete executor need to end up with
       a heap that has the same chunks in the same order. This can be relaxed
       later to allow permutations or even some kind of semantic equivalence. *)
    Definition represents {Γ Σ} (ι : SymInstance Σ) (s__sym : SymbolicState Γ Σ) (s__sc : SCState Γ) : Prop :=
      inst ι (symbolicstate_heap s__sym)       = scstate_heap s__sc /\
      inst ι (symbolicstate_localstore s__sym) = scstate_localstore s__sc /\
      inst ι (symbolicstate_pathcondition s__sym).

    (* This is a preservation lemma for state representation. The symbolic
       executor is allwed to add a formula (local assumption) to the
       path-condition if it's true for the current instance ι. We only
       need the -> direction I think. *)
    Lemma represents_assume_formula {Γ Σ} (ι : SymInstance Σ) (s__sym : SymbolicState Γ Σ) (s__sc : SCState Γ) fml :
      represents ι s__sym s__sc /\ inst ι fml <->
      represents ι (symbolicstate_assume_formula fml s__sym) s__sc.
    Proof.
      unfold represents; destruct s__sym, s__sc. cbn - [inst].
      rewrite inst_pathcondition_cons. intuition.
    Qed.

    Lemma represents_produce_chunk {Γ Σ} (ι : SymInstance Σ) (c1 : Chunk Σ) (c2 : SCChunk)
          (s__sym : SymbolicState Γ Σ) (s__sc : SCState Γ) :
      represents ι s__sym s__sc /\ c2 = inst ι c1 <->
      represents ι (symbolicstate_produce_chunk c1 s__sym) (scstate_produce_chunk c2 s__sc).
    Proof.
      unfold represents; destruct s__sym, s__sc; cbn - [inst].
      change (inst ι (cons c1 ?h)) with (cons (inst ι c1) (inst ι h)).
      split; intros H; destruct_propositional H; subst; intuition.
      now dependent elimination H1.
    Qed.

    (* This is another preservation lemma. This one covers every state change in
       the symbolic executor that is implemented via a universal variable
       substitution, i.e. local equality assumptions that are substituted right
       away and allocation of fresh universal variables. The converse <- also
       holds, but has very strong assumptions. A more general relation
       between symbolic states is encoded by state_geq below. *)
    Lemma represents_rel {Γ Σ0 Σ1} (ζ1 : Sub Σ0 Σ1) (ι0 : SymInstance Σ0) (ι1 : SymInstance Σ1) :
      syminstance_rel ζ1 ι0 ι1 ->
      forall (s__sym : SymbolicState Γ Σ0) (s__sc : SCState Γ),
        represents ι0 s__sym s__sc <->
        represents ι1 (subst ζ1 s__sym) s__sc.
    Proof.
      unfold syminstance_rel, represents; intros. subst.
      destruct s__sym as [pc δ__sym h__sym], s__sc as [δ__sc h__sc]; cbn.
      now rewrite !inst_subst.
    Qed.

    Definition ResultProperty Γ A Σ :=
      DynamicMutatorResult Γ A Σ -> Prop.

    Definition state_geq {Γ Σ0 Σ1} (ζ1 : Sub Σ0 Σ1)
      (s__sym0 : SymbolicState Γ Σ0) (s__sym1 : SymbolicState Γ Σ1) : Prop :=
      forall (ι0 : SymInstance Σ0) (ι1 : SymInstance Σ1),
        syminstance_rel ζ1 ι0 ι1 ->
        forall (s__sc : SCState Γ),
          represents ι1 s__sym1 s__sc ->
          represents ι0 s__sym0 s__sc.

    Lemma state_geq_subst {Γ Σ0 Σ1} (ζ1 : Sub Σ0 Σ1) (s0 : SymbolicState Γ Σ0) (s1 : SymbolicState Γ Σ1) :
      s1 = subst ζ1 s0 ->
      state_geq ζ1 s0 s1.
    Proof. intros -> ? ? ? ?. now apply represents_rel. Qed.

    Definition dmutres_geq_syn {Γ A Σ} `{Subst A} (r1 r2 : DynamicMutatorResult Γ A Σ) : Prop :=
      match r1 , r2 with
      | MkDynMutResult ζ1 a1 s1, MkDynMutResult ζ2 a2 s2 =>
        exists ζ12,
        ζ2 = sub_comp ζ1 ζ12 /\
        a2 = subst ζ12 a1 /\
        s2 = subst ζ12 s1
      end.

    Definition dmutres_geq_sem {Γ A V Σ} {instA : Inst A V} (r1 r2 : DynamicMutatorResult Γ A Σ) : Prop :=
      match r1 , r2 with
      | MkDynMutResult ζ1 a1 s1, MkDynMutResult ζ2 a2 s2 =>
        exists ζ12,
        forall ι1 ι2,
          syminstance_rel ζ12 ι1 ι2 ->
          forall s__sc,
            represents ι2 s2 s__sc ->
            represents ι1 s1 s__sc /\
            inst ι1 a1 = inst ι2 a2 /\
            inst ι1 ζ1 = inst ι2 ζ2
      end.

    Lemma dmutres_geq_syn_sem {Γ A V Σ} `{InstLaws A V} :
      forall r1 r2 : DynamicMutatorResult Γ A Σ,
        dmutres_geq_syn r1 r2 ->
        dmutres_geq_sem r1 r2.
    Proof.
      intros [Σ1 ζ1 a1 s1] [Σ2 ζ2 a2 s2] [ζ12 (-> & -> & ->)]; cbn - [inst].
      exists ζ12. intros ? ? <- ? rep.
      split. revert rep. apply represents_rel. reflexivity.
      unfold sub_comp. rewrite ?inst_subst. auto.
    Qed.

    Global Instance dmutres_geq_sem_preorder {Γ A V Σ} `{instLA : InstLaws A V} : PreOrder (@dmutres_geq_sem Γ A V Σ _).
    Proof.
      constructor.
      - intros [Σ1 ζ1 a1 s]. cbn - [inst]. exists (sub_id _).
        intros * ->%syminstance_rel_refl_inv. auto.
      - intros [Σ1 ζ1 a1 s1] [Σ2 ζ2 a2 s2] [Σ3 ζ3 a3 s3]. cbn - [inst].
        intros [ζ12] [ζ23].
        exists (sub_comp ζ12 ζ23).
        intros ι1 ι3 rel13 sc rep3.
        apply syminstance_rel_comp in rel13.
        remember (inst ι3 ζ23) as ι2.
        assert (syminstance_rel ζ23 ι2 ι3).
        now unfold syminstance_rel.
        specialize (H3 _ _ H4 _ rep3). destruct_conjs.
        specialize (H2 _ _ rel13 _ H3). destruct_conjs.
        split; auto. split; congruence.
    Qed.

    Lemma dmutres_geq_sem_pre_comp {A AV} {instA : Inst A AV} {Γ Σ1 Σ2 Σ3}
          (ζ2 : Sub Σ1 Σ2) (a2 : A Σ2) (s2 : SymbolicState Γ Σ2)
          (ζ3 : Sub Σ1 Σ3) (a3 : A Σ3) (s3 : SymbolicState Γ Σ3) :
      forall Σ0 (ζ1 : Sub Σ0 Σ1),
        dmutres_geq_sem
          {| dmutres_context := Σ2; dmutres_substitution := ζ2; dmutres_result_value := a2; dmutres_result_state := s2 |}
          {| dmutres_context := Σ3; dmutres_substitution := ζ3; dmutres_result_value := a3; dmutres_result_state := s3 |} ->
        dmutres_geq_sem
          {| dmutres_context := Σ2; dmutres_substitution := sub_comp ζ1 ζ2; dmutres_result_value := a2; dmutres_result_state := s2 |}
          {| dmutres_context := Σ3; dmutres_substitution := sub_comp ζ1 ζ3; dmutres_result_value := a3; dmutres_result_state := s3 |}.
    Proof.
      intros ? ? [ζ23 H]. exists ζ23.
      intros ? ? Hrel. specialize (H _ _ Hrel).
      intros ? Hrep. specialize (H _ Hrep).
      unfold sub_comp. rewrite ?inst_subst.
      intuition congruence.
    Qed.

    Definition resultprop_specialize {Γ A Σ1 Σ2} (ζ : Sub Σ1 Σ2) :
      ResultProperty Γ A Σ1 -> ResultProperty Γ A Σ2 :=
      fun p r => p (cosubst_dmutres ζ r).

    Definition resultprop_downwards_closed {Γ AT Σ A} `{Inst AT A} (p : ResultProperty Γ AT Σ) : Prop :=
      forall (r1 r2 : DynamicMutatorResult Γ AT Σ),
        dmutres_geq_sem r1 r2 -> p r1 -> p r2.

    Lemma resultprop_specialize_dcl {Γ A AV Σ1 Σ2} `{Inst A AV} (ζ : Sub Σ1 Σ2) (POST : ResultProperty Γ A Σ1) (POST_dcl : resultprop_downwards_closed POST) :
      resultprop_downwards_closed (resultprop_specialize ζ POST).
    Proof.
      unfold resultprop_downwards_closed, resultprop_specialize.
      intros [Σ3 ζ3 a3 s3] [Σ4 ζ4 a4 s4] [ζ34]. apply POST_dcl. exists ζ34.
      intros ? ? Hrel ? Hrep. specialize (H0 _ _ Hrel _ Hrep).
      unfold sub_comp. rewrite ?inst_subst.
      intuition congruence.
    Qed.

    Lemma resultprop_specialize_id {Γ A Σ} (P : ResultProperty Γ A Σ) :
      forall r, resultprop_specialize (sub_id _) P r <-> P r.
    Proof.
      intros [Σ' ζ a s]; unfold resultprop_specialize; cbn.
      now rewrite sub_comp_id_left.
    Qed.

    Lemma resultprop_specialize_comp {Γ A Σ1 Σ2 Σ3} (ζ12 : Sub Σ1 Σ2) (ζ23 : Sub Σ2 Σ3) (P : ResultProperty Γ A Σ1) :
      forall r,
        resultprop_specialize (sub_comp ζ12 ζ23) P r <->
        resultprop_specialize ζ23 (resultprop_specialize ζ12 P) r.
    Proof.
      intros [Σ' ζ a s]; unfold resultprop_specialize; cbn.
      now rewrite sub_comp_assoc.
    Qed.

    Definition StateProperty Γ A Σ :=
      forall Σ1, Sub Σ Σ1 -> A Σ1 -> SymbolicState Γ Σ1 -> Prop.

    Definition stateprop_specialize {Γ A Σ1 Σ2} (ζ : Sub Σ1 Σ2) (p: StateProperty Γ A Σ1) :
      StateProperty Γ A Σ2 := fun Σ3 ζ3 => p Σ3 (sub_comp ζ ζ3).

    Definition stateprop_impl {Γ A Σ} (P Q : StateProperty Γ A Σ) : Prop :=
      forall Σ1 (ζ : Sub Σ Σ1) (a : A Σ1) (s : SymbolicState Γ Σ1),
        P Σ1 ζ a s -> Q Σ1 ζ a s.

    Definition stateprop_downwards_closed {Γ Σ A AV} `{Inst A AV} (p : StateProperty Γ A Σ) : Prop :=
      forall Σ1 (ζ1 : Sub Σ Σ1) a1 s1 Σ2 (ζ2 : Sub Σ Σ2) a2 s2,
        dmutres_geq_sem (MkDynMutResult ζ1 a1 s1) (MkDynMutResult ζ2 a2 s2) ->
        p Σ1 ζ1 a1 s1 -> p Σ2 ζ2 a2 s2.

    Local Notation "[ ι ] x == y" := (inst ι x = inst ι y) (at level 50).

    (* Read: If ς is equivalent to t in ι, then substituting t for ς is equivalent to the identity. *)
    Lemma inst_single_shift {Σ ς σ} (ςInΣ : ς :: σ ∈ Σ) (t : Term (Σ - (ς :: σ)) σ) ι :
      [ ι ] term_var ς == subst (sub_shift ςInΣ) t ->
      [ ι ] sub_comp (sub_single ςInΣ t) (sub_shift ςInΣ) == sub_id _.
    Proof.
      intros H.
      apply env_lookup_extensional; cbn.
      intros [] bIn.
      unfold sub_id, sub_comp, subst, SubstEnv, inst; cbn.
      rewrite ?env_lookup_map, ?env_lookup_tabulate.
      pose proof (occurs_check_var_spec ςInΣ bIn).
      destruct (occurs_check_var ςInΣ bIn) eqn:?.
      - dependent elimination e. cbn in H0. subst.
        rewrite lookup_sub_single_eq. symmetry. exact H.
      - f_equal.
        destruct H0. subst bIn.
        rewrite lookup_sub_single_neq.
        cbn. unfold sub_shift.
        rewrite env_lookup_tabulate.
        reflexivity.
    Qed.

    (* Lemma inst_pathcondition_swap {Σ} (ι : SymInstance Σ) a b pc : *)
    (*   inst_pathcondition ι (a :: b :: pc)%list -> *)
    (*   inst_pathcondition ι (b :: a :: pc)%list. *)
    (* Proof. *)
    (*   intros Hpc. *)
    (*   destruct Hpc as [Ha Hpc]. *)
    (*   destruct Hpc as [Hb Hpc]. *)
    (*   split. assumption. *)
    (*   split. assumption. *)
    (*   assumption. *)
    (* Qed. *)

    Lemma dmutres_try_assume_eq_spec {Γ Σ σ} (s__sym : SymbolicState Γ Σ) (t1 t2 : Term Σ σ)
      (POST : ResultProperty Γ Unit Σ) (POST_dcl : resultprop_downwards_closed POST) :
      OptionSpec
        (fun r => POST r <->
                  POST (MkDynMutResult
                          (sub_id Σ)
                          tt
                          (symbolicstate_assume_formula (formula_eq t1 t2) s__sym)))
        True
        (dmutres_try_assume_eq s__sym t1 t2).
    Proof.
      destruct t1; cbn; try (constructor; auto; fail).
      destruct (occurs_check ςInΣ t2) eqn:?; constructor; auto.
      apply (@occurs_check_sound _ _ (@OccursCheckTerm _)) in Heqo;
      auto with typeclass_instances. subst t2.
      split.
      - apply POST_dcl. exists (sub_shift ςInΣ).
        intros * rel12 ? rep2.
        apply represents_assume_formula in rep2. destruct rep2.
        apply inst_single_shift in H0.
        rewrite inst_sub_id in H0.
        split.
        + revert H. apply represents_rel.
          revert rel12. intros <-.
          now apply syminstance_rel_comp.
        + split; auto.
          revert rel12. intros <-.
          now rewrite inst_sub_id, <- ?inst_subst.
      - apply POST_dcl. exists (sub_single ςInΣ t).
        intros * <- ? rep2.
        apply (represents_rel eq_refl) in rep2.
        rewrite inst_sub_id. split; auto.
        apply represents_assume_formula. split; auto.
        rewrite <- ?inst_subst.
        cbn.
        rewrite <- subst_sub_comp.
        rewrite sub_comp_shift_single, subst_sub_id.
        rewrite lookup_sub_single_eq.
        reflexivity.
    Qed.

    Lemma dmutres_assume_formula_spec {Γ Σ} (s__sym : SymbolicState Γ Σ) (fml : Formula Σ)
      (POST : ResultProperty Γ Unit Σ) (POST_dcl : resultprop_downwards_closed POST) :
      POST (dmutres_assume_formula s__sym fml) <->
      POST (MkDynMutResult
              (sub_id Σ)
              tt
              (symbolicstate_assume_formula fml s__sym)).
    Proof.
      split.
      - destruct fml; cbn; auto.
        destruct (dmutres_try_assume_eq_spec s__sym t1 t2 POST_dcl). apply H. clear H.
        destruct (dmutres_try_assume_eq_spec s__sym t2 t1 POST_dcl); auto.
        intros Hpost. apply H in Hpost. clear a H. revert Hpost.
        apply POST_dcl. exists (sub_id _). intros ? ? <- ? Hrep.
        rewrite ?inst_sub_id; split; auto.
        apply represents_assume_formula in Hrep. destruct Hrep as [Hrep Hfml].
        apply represents_assume_formula. split; auto.
        revert Hfml; now cbn.
      - destruct fml; cbn; auto.
        destruct (dmutres_try_assume_eq_spec s__sym t1 t2 POST_dcl). apply H. clear H.
        destruct (dmutres_try_assume_eq_spec s__sym t2 t1 POST_dcl); auto.
        intros Hpost. apply H. clear a H. revert Hpost.
        apply POST_dcl. exists (sub_id _). intros ? ? <- ? Hrep.
        rewrite ?inst_sub_id; split; auto.
        apply represents_assume_formula in Hrep. destruct Hrep as [Hrep Hfml].
        apply represents_assume_formula. split; auto.
        revert Hfml; now cbn.
    Qed.

    Lemma subst_symbolicstate_assume_formula {Γ Σ1 Σ2} (ζ : Sub Σ1 Σ2)
          (f : Formula Σ1) (s : SymbolicState Γ Σ1) :
      subst ζ (symbolicstate_assume_formula f s) =
      symbolicstate_assume_formula (subst ζ f) (subst ζ s).
    Proof. now destruct s. Qed.

    (* These should be kept abstract in the rest of the proof. If you need some
       property, add a lemma above. *)
    Local Opaque inst_chunk.
    Local Opaque inst_heap.
    Local Opaque inst_pathcondition.
    Local Opaque instantiate_env.
    Local Opaque instantiate_list.
    Local Opaque represents.
    Local Opaque symbolicstate_assume_formula.
    Local Opaque symbolicstate_produce_chunk.
    Local Opaque dmutres_assume_formula.

    Definition scmut_wp {Γ1 Γ2 A}
      (m : SCMut Γ1 Γ2 A)
      (POST : A -> SCState Γ2 -> Prop)
      (s1 : SCState Γ1) : Prop :=
      outcome_satisfy (m s1) (fun r => POST (scmutres_value r) (scmutres_state r)).

    Lemma scmut_wp_bind {Γ1 Γ2 Γ3 A B} (ma : SCMut Γ1 Γ2 A) (f : A -> SCMut Γ2 Γ3 B)
          (POST : B -> SCState Γ3 -> Prop) :
      forall s1 : SCState Γ1,
        scmut_wp (scmut_bind ma f) POST s1 <->
        scmut_wp ma (fun a => scmut_wp (f a) POST) s1.
    Proof.
      unfold SCMut, scmut_bind, scmut_wp in *; cbn; intros.
      now rewrite outcome_satisfy_bind.
    Qed.

    Definition dmut_wp {Γ1 Γ2 Σ0 A}
      (m : DynamicMutator Γ1 Γ2 A Σ0)
      (POST : StateProperty Γ2 A Σ0)
      (s1 : SymbolicState Γ1 Σ0) : Prop :=
      forall Σ1 (ζ1 : Sub Σ0 Σ1),
        outcome_satisfy
          (m Σ1 ζ1 (subst ζ1 s1))
          (fun '(@MkDynMutResult _ _ _ Σ2 ζ2 a2 s2) =>
             POST Σ2 (sub_comp ζ1 ζ2) a2 s2).

    Lemma dmut_wp_monotonic {Γ1 Γ2 Σ0 A} (m : DynamicMutator Γ1 Γ2 A Σ0)
          (P Q : StateProperty Γ2 A Σ0) (HYP : stateprop_impl P Q) :
      forall (s1 : SymbolicState Γ1 Σ0),
        dmut_wp m P s1 -> dmut_wp m Q s1.
    Proof.
      unfold dmut_wp; cbn; intros s1 H Σ1 ζ1.
      specialize (H Σ1 ζ1). revert H.
      apply outcome_satisfy_monotonic.
      intros [Σ2 ζ2 a2 s2]; cbn.
      intuition.
    Qed.

    Definition stateprop_lift {Γ AT A Σ} {instA : Inst AT A} (ι : SymInstance Σ) (POST : A -> SCState Γ -> Prop) :
      StateProperty Γ AT Σ :=
      fun Σ1 ζ1 v1 s__sym1 =>
        forall ι1,
          syminstance_rel ζ1 ι ι1 ->
          forall s__sc1,
            represents ι1 s__sym1 s__sc1 ->
            POST (inst ι1 v1) s__sc1.

    Lemma stateprop_lift_dcl {Γ AT A Σ} `{InstLaws AT A} (ι1 : SymInstance Σ) (POST : A -> SCState Γ -> Prop) :
      stateprop_downwards_closed (stateprop_lift ι1 POST).
    Proof.
      unfold stateprop_downwards_closed, stateprop_lift.
      intros Σ3 ζ3 a3 s3 Σ4 ζ4 a4 s4 [ζ34 Hgeq] Hpost ι2 r12 ? ?.
      specialize (Hgeq (inst ι2 ζ34) ι2 eq_refl _ H3). destruct_conjs.
      specialize (Hpost (inst ι2 ζ34)).
      unfold syminstance_rel in Hpost.
      rewrite H6 in Hpost. specialize (Hpost r12 _ H4).
      rewrite H5 in Hpost. apply Hpost.
    Qed.

    Definition resultprop_lift {Γ AT A Σ1} {instA : Inst AT A} (ι1 : SymInstance Σ1) (POST : A -> SCState Γ -> Prop) :
      ResultProperty Γ AT Σ1 :=
      fun dres =>
        match dres with
        | @MkDynMutResult _ _ _ Σ2 ζ2 a2 s2 =>
          stateprop_lift ι1 POST ζ2 a2 s2
        end.

    Definition resultprop_lift_dcl {Γ AT A Σ1} `{InstLaws AT A} (ι1 : SymInstance Σ1) (POST : A -> SCState Γ -> Prop) :
      resultprop_downwards_closed (resultprop_lift ι1 POST).
    Proof.
      unfold resultprop_downwards_closed, resultprop_lift.
      intros [Σ3 ζ3 a3 s3] [Σ4 ζ4 a4 s4].
      apply stateprop_lift_dcl.
    Qed.

    Definition APPROX Γ1 Γ2 AT A {instA : Inst AT A} : Type :=
      forall Σ (ι : SymInstance Σ),
        DynamicMutator Γ1 Γ2 AT Σ -> SCMut Γ1 Γ2 A -> Prop.
    Arguments APPROX _ _ _ _ {_}.

    Definition box {Γ1 Γ2 AT A} {instA : Inst AT A} (R : APPROX Γ1 Γ2 AT A) : APPROX Γ1 Γ2 AT A :=
      fun Σ ι dm sm =>
        forall Σ1 (ζ1 : Sub Σ Σ1) (ι1 : SymInstance Σ1),
          syminstance_rel ζ1 ι ι1 ->
          R Σ1 ι1 (dmut_sub ζ1 dm) sm.

    Lemma box_proj {Γ1 Γ2 AT A} {instA : Inst AT A} (R : APPROX Γ1 Γ2 AT A) :
      forall Σ (ι : SymInstance Σ) dm sm,
        box R ι dm sm -> R _ ι dm sm.
    Proof.
      intros ? ? ? ? b.
      unfold box in b.
      inster b by apply syminstance_rel_refl.
      unfold dmut_sub in b.
      (* apply b. *)
    Admitted.

    Definition box_box {Γ1 Γ2 AT A} {instA : Inst AT A} (R : APPROX Γ1 Γ2 AT A) :
      forall Σ (ι : SymInstance Σ) dm sm,
        box R ι dm sm -> box (box R) ι dm sm.
    Proof.
      intros ? ? ? ?. unfold box. intros bb Σ1 ζ1 ι1 ? Σ2 ζ2 ι2 ?.
      specialize (bb Σ2 (sub_comp ζ1 ζ2) ι2).
      inster bb by eapply syminstance_rel_trans; eauto.
      (* apply bb. *)
    Admitted.

    Definition approximates {Γ1 Γ2 AT A} {instA : Inst AT A} : APPROX Γ1 Γ2 AT A :=
      fun Σ ι dm sm =>
        forall (s__sym : SymbolicState Γ1 Σ) (s__sc : SCState Γ1),
          represents ι s__sym s__sc ->
          forall (POST : A -> SCState Γ2 -> Prop),
            dmut_wp dm (stateprop_lift ι POST) s__sym ->
            scmut_wp sm POST s__sc.

    Lemma approximates_proj {Γ1 Γ2 AT A} {instA : Inst AT A} {Σ} (ι : SymInstance Σ)
      (dm : DynamicMutator Γ1 Γ2 AT Σ) (sm : SCMut Γ1 Γ2 A) :
      box approximates ι dm sm -> approximates ι dm sm.
    Proof.
      unfold approximates, box. intros.
      inster H by apply syminstance_rel_refl.
      inster H by eauto. apply H. clear H.
      unfold dmut_wp, dmut_sub in *. intros Σ1 ζ1.
      rewrite sub_comp_id_left. apply H1.
    Qed.

    Lemma approximates_box_box {Γ1 Γ2 AT A} {instA : Inst AT A} {Σ} (ι : SymInstance Σ)
      (dm : DynamicMutator Γ1 Γ2 AT Σ) (sm : SCMut Γ1 Γ2 A) :
      box approximates ι dm sm -> box (box approximates) ι dm sm.
    Proof.
      unfold approximates, box, dmut_wp, dmut_sub. intros.
      inster H by eapply syminstance_rel_trans; eauto.
      inster H by eauto. apply H. clear H. intros. now rewrite sub_comp_assoc.
    Qed.

    Lemma approximates_sub {Γ Σ Σ1} (ζ1 : Sub Σ Σ1) (ι : SymInstance Σ) (ι1 : SymInstance Σ1)
      (relι1 : syminstance_rel ζ1 ι ι1) (d : DynamicMutator Γ Γ Unit Σ) (s : SCMut Γ Γ unit) :
      box approximates ι d s -> box approximates ι1 (dmut_sub ζ1 d) s.
    Proof. intros H. eapply approximates_box_box; eauto. Qed.

    Lemma scmut_wp_demonic_binary {Γ1 Γ2 A} (sm1 sm2 : SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_demonic_binary sm1 sm2) POST s__sc <->
      scmut_wp sm1 POST s__sc /\ scmut_wp sm2 POST s__sc.
    Proof. unfold scmut_wp, scmut_demonic_binary; cbn; intuition. Qed.

    Lemma dmut_wp_demonic_binary {Γ1 Γ2 Σ A} (m1 m2 : DynamicMutator Γ1 Γ2 A Σ)
      (POST : StateProperty Γ2 A Σ) (s : SymbolicState Γ1 Σ) :
        dmut_wp (dmut_demonic_binary m1 m2) POST s <->
        dmut_wp m1 POST s /\ dmut_wp m2 POST s.
    Proof. unfold dmut_wp, dmut_demonic_binary; cbn; intuition. Qed.

    Lemma dmut_wp_sub_demonic_binary {Γ1 Γ2 Σ A Σ1} (ζ1 : Sub Σ Σ1) (m1 m2 : DynamicMutator Γ1 Γ2 A Σ)
      (POST : StateProperty Γ2 A Σ1) (s : SymbolicState Γ1 Σ1) :
        dmut_wp (dmut_sub ζ1 (dmut_demonic_binary m1 m2)) POST s <->
        dmut_wp (dmut_sub ζ1 m1) POST s /\ dmut_wp (dmut_sub ζ1 m2) POST s.
    Proof. unfold dmut_wp, dmut_demonic_binary; cbn; intuition. Qed.

    Lemma approximates_demonic_binary {Γ1 Γ2 Σ} (ι : SymInstance Σ)
          (dm1 dm2 : DynamicMutator Γ1 Γ2 Unit Σ) (sm1 sm2 : SCMut Γ1 Γ2 unit) :
      box approximates ι dm1 sm1 ->
      box approximates ι dm2 sm2 ->
      box approximates ι (dmut_demonic_binary dm1 dm2) (scmut_demonic_binary sm1 sm2).
    Proof.
      unfold box. intros H1 H2 Σ1 ζ1 ι1 H__ι.
      specialize (H1 Σ1 ζ1 ι1 H__ι). specialize (H2 Σ1 ζ1 ι1 H__ι).
      intros ? ? H__s POST. specialize (H1 _ _ H__s POST). specialize (H2 _ _ H__s POST).
      intros H. apply dmut_wp_sub_demonic_binary in H. destruct H.
      apply scmut_wp_demonic_binary. split; auto.
    Qed.

    Lemma scmut_wp_demonic {Γ1 Γ2 A B} (sm : B -> SCMut Γ1 Γ2 A) (s__sc : SCState Γ1) (POST : A -> SCState Γ2 -> Prop) :
      scmut_wp (scmut_demonic sm) POST s__sc <-> forall v, scmut_wp (sm v) POST s__sc.
    Proof. unfold scmut_wp, scmut_demonic; cbn; intuition. Qed.

    Lemma dmut_wp_demonic {Γ1 Γ2 Σ A B} (m : B -> DynamicMutator Γ1 Γ2 A Σ)
      (POST : StateProperty Γ2 A Σ) (s : SymbolicState Γ1 Σ) :
        dmut_wp (dmut_demonic m) POST s <->
        forall b, dmut_wp (m b) POST s.
    Proof. unfold dmut_wp, dmut_demonic; cbn; intuition. Qed.

    Lemma subst_symbolicstate_produce_chunk {Γ Σ Σ1} (ζ1 : Sub Σ Σ1) (c : Chunk Σ) (s : SymbolicState Γ Σ) :
      subst ζ1 (symbolicstate_produce_chunk c s) = symbolicstate_produce_chunk (subst ζ1 c) (subst ζ1 s).
    Proof. now destruct s. Qed.

    Lemma dmut_wp_produce_chunk {Γ Σ Σ1} (ζ1 : Sub Σ Σ1) (c : Chunk _) (s__sym : SymbolicState Γ _)
          (POST : StateProperty Γ Unit _) (POST_dcl : stateprop_downwards_closed POST) :
      dmut_wp (dmut_sub ζ1 (dmut_produce_chunk c)) POST s__sym <->
      POST Σ1 (sub_id Σ1) tt (symbolicstate_produce_chunk (subst ζ1 c) s__sym).
    Proof.
      split.
      - intros dwp.
        specialize (dwp Σ1 (sub_id Σ1)). cbn in dwp.
        now rewrite ?sub_comp_id_right, ?subst_sub_id in dwp.
      - intros p Σ2 ζ2. cbn. rewrite subst_sub_comp. revert p.
        rewrite <- subst_symbolicstate_produce_chunk.
        rewrite sub_comp_id_right. change tt with (subst ζ2 tt).
        apply POST_dcl. apply dmutres_geq_syn_sem.
        exists ζ2. now rewrite sub_comp_id_left.
    Qed.

    Lemma dmut_produce_chunk_sound {Γ Σ} (ι : SymInstance Σ) (c : Chunk Σ) :
      box approximates
        (Γ1 := Γ) (Γ2 := Γ) ι
        (dmut_produce_chunk c)
        (scmut_produce_chunk (inst ι c)).
    Proof.
      intros ? ? ? ? ? ? Hrep ? dwp. cbn.
      apply dmut_wp_produce_chunk in dwp; auto using stateprop_lift_dcl.
      apply (dwp ι1); auto using syminstance_rel_refl.
      apply represents_produce_chunk; split; auto.
      rewrite inst_subst. unfold syminstance_rel in H. now subst.
    Qed.

    Lemma dmut_assume_formula_sound {Γ Σ} (ι : SymInstance Σ) (fml : Formula Σ) :
      box approximates
        (Γ1 := Γ) (Γ2 := Γ) ι
        (dmut_assume_formula fml)
        (scmut_assume_formula ι fml).
    Proof.
      intros ? ? ? ? ? ? H__state POST H.
      unfold dmut_wp, dmut_sub, dmut_assume_formula in H.
      specialize (H Σ1 (sub_id Σ1)).
      rewrite sub_comp_id_right in H.
      unfold scmut_wp, scmut_assume_formula. cbn. intros.
      rewrite ?subst_sub_id in H.
      destruct (try_solve_formula_spec (subst ζ1 fml)).
      - specialize (H2 ι1).
        unfold syminstance_rel in H0. subst.
        rewrite <- inst_subst in H1.
        apply H2 in H1. clear H2.
        unfold is_true in H1. subst a.
        cbn in H.
        rewrite ?sub_comp_id_left in H.
        unfold stateprop_lift in H.
        inster H by apply syminstance_rel_refl.
        now apply H.
      - destruct (dmutres_assume_formula s__sym (subst ζ1 fml)) as [Σ2 ζ2 [] s2] eqn:?.
        cbn in H. rewrite sub_comp_id_left in H.
        assert (resultprop_lift ι1 POST (dmutres_assume_formula s__sym (subst ζ1 fml)))
          by (rewrite Heqd; apply H).
        apply dmutres_assume_formula_spec in H3; auto using resultprop_lift_dcl.
        unfold resultprop_lift, stateprop_lift in H3.
        inster H3 by apply syminstance_rel_refl. apply H3.
        apply represents_assume_formula. split; auto.
        rewrite inst_subst. unfold syminstance_rel in H0; now subst.
    Qed.

    Definition dmut_wf {Γ1 Γ2 AT Σ0 A} `{Inst AT A} (d : DynamicMutator Γ1 Γ2 AT Σ0) : Prop :=
      forall Σ1 Σ2 (ζ1 : Sub Σ0 Σ1) (ζ2 : Sub Σ1 Σ2) (s1 : SymbolicState Γ1 Σ1)
             (POST : ResultProperty Γ2 AT Σ1) (POST_dcl : resultprop_downwards_closed POST),
        outcome_satisfy (d Σ1 ζ1 s1) POST ->
        outcome_satisfy (d Σ2 (sub_comp ζ1 ζ2) (subst ζ2 s1)) (resultprop_specialize ζ2 POST).

    Lemma dmut_wf_pure {Γ AT Σ A} {subA: Subst AT} {sublAT: SubstLaws AT}
          {instA : Inst AT A} {instlA : InstLaws AT A} (a : AT Σ) :
      dmut_wf (dmut_pure (Γ := Γ) a).
    Proof.
      unfold dmut_wf, resultprop_specialize; cbn; intros.
      revert H.
      apply POST_dcl.
      exists ζ2; cbn. intros ? ? rel ? rep.
      split.
      - revert rep. now apply represents_rel.
      - revert rel. intros <-.
        rewrite inst_sub_id, sub_comp_id_right, subst_sub_comp.
        now rewrite ?inst_subst.
    Qed.

    Lemma dmut_wf_sub {Γ1 Γ2 AT A Σ0} {instA : Inst AT A} (d : DynamicMutator Γ1 Γ2 AT Σ0) (wf_d : dmut_wf d) :
      forall (Σ1 : LCtx) (ζ1 : Sub Σ0 Σ1), dmut_wf (dmut_sub ζ1 d).
    Proof.
      intros Σ1 ζ1 Σ2 Σ3 ζ2 ζ3 s2 POST POST_dcl. unfold dmut_sub.
      rewrite <- sub_comp_assoc. now apply wf_d.
    Qed.

    Lemma dmut_wf_demonic_binary {Γ1 Γ2 AT A Σ0} `{Inst AT A} (d1 d2 : DynamicMutator Γ1 Γ2 AT Σ0) (wf_d1 : dmut_wf d1) (wf_d2 : dmut_wf d2) :
      dmut_wf (dmut_demonic_binary d1 d2).
    Proof.
      unfold dmut_wf, dmut_demonic_binary in *. cbn.
      intros * POST_dcl [H1 H2].
      split.
      - revert H1. now apply wf_d1.
      - revert H2. now apply wf_d2.
    Qed.

    Lemma dmut_wf_angelic_binary {Γ1 Γ2 AT A Σ0} `{Inst AT A} (d1 d2 : DynamicMutator Γ1 Γ2 AT Σ0) (wf_d1 : dmut_wf d1) (wf_d2 : dmut_wf d2) :
      dmut_wf (dmut_angelic_binary d1 d2).
    Proof.
      unfold dmut_wf, dmut_angelic_binary in *. cbn.
      intros * POST_dcl [H1|H1].
      - left. revert H1. now apply wf_d1.
      - right. revert H1. now apply wf_d2.
    Qed.

    Module WfExperiments.

      Definition dmutres_pathcondition {Γ AT Σ} (r : DynamicMutatorResult Γ AT Σ) : PathCondition (dmutres_context r).
      Proof. eapply symbolicstate_pathcondition, dmutres_result_state. Defined.

      Definition pc_geq {Σ1 Σ2} (ζ12 : Sub Σ1 Σ2) (pc1 : PathCondition Σ1) (pc2 : PathCondition Σ2) : Prop :=
        forall ι1 ι2,
          syminstance_rel ζ12 ι1 ι2 ->
          (inst ι2 pc2 : Prop) ->
          (inst ι1 pc1 : Prop).

      Definition outcome_result_geq {Γ AT A} `{Inst AT A} {Σ1 Σ2} (ζ12 : Sub Σ1 Σ2)
        (pc2 : PathCondition Σ2)
        (or1 : Outcome (DynamicMutatorResult Γ AT Σ1))
        (or2 : Outcome (DynamicMutatorResult Γ AT Σ2)) : Prop :=
          forall
            (P : ResultProperty Γ AT _) (P_dcl : resultprop_downwards_closed P)
            (Q : ResultProperty Γ AT _) (Q_dcl : resultprop_downwards_closed Q)
            (PQ : forall r,
                pc_geq (dmutres_substitution r) pc2 (dmutres_pathcondition r) ->
                resultprop_specialize ζ12 P r ->
                Q r)
            (QP : forall r,
                pc_geq (dmutres_substitution r) pc2 (dmutres_pathcondition r) ->
                Q r ->
                resultprop_specialize ζ12 P r),
          outcome_satisfy or1 P ->
          outcome_satisfy or2 Q.

      Definition dmut_geq {Γ1 Γ2 AT A} `{Inst AT A} {Σ0 Σ1}
        (d0 : DynamicMutator Γ1 Γ2 AT Σ0)
        (d1 : DynamicMutator Γ1 Γ2 AT Σ1) : Prop :=
        forall Σ2 Σ3 (ζ02 : Sub Σ0 Σ2) (ζ13 : Sub Σ1 Σ3) (ζ23 : Sub Σ2 Σ3) s2 s3,
          state_geq ζ23 s2 s3 ->
          outcome_result_geq ζ23 (symbolicstate_pathcondition s3) (d0 Σ2 ζ02 s2) (d1 Σ3 ζ13 s3).

      Definition dmut_wf {Γ1 Γ2 AT Σ0 A} `{Inst AT A} (d : DynamicMutator Γ1 Γ2 AT Σ0) : Prop :=
        forall Σ1 Σ2 (ζ1 : Sub Σ0 Σ1) (ζ2 : Sub Σ0 Σ2) (ζ12 : Sub Σ1 Σ2) s1 s2,
          state_geq ζ12 s1 s2 ->
          outcome_result_geq ζ12 (symbolicstate_pathcondition s2) (d Σ1 ζ1 s1) (d Σ2 ζ2 s2).

      Lemma dmut_wf_geq_id {Γ1 Γ2 AT Σ0 A} `{Inst AT A} (d : DynamicMutator Γ1 Γ2 AT Σ0) :
        dmut_wf d <-> dmut_geq d d.
      Proof. unfold dmut_wf, dmut_geq. reflexivity. Qed.

      Definition DynamicMutatorArrow' Γ1 Γ2 A B Σ0 : Type :=
        forall Σ1,
          Sub Σ0 Σ1 -> A Σ1 ->
          SymbolicState Γ1 Σ1 -> Outcome (DynamicMutatorResult Γ2 B Σ1).

      Definition dmut_wf_arrow' {Γ1 Γ2 AT A BT B Σ0} `{Inst AT A, Inst BT B}
        (f : DynamicMutatorArrow' Γ1 Γ2 AT BT Σ0) : Prop :=
        forall Σ1 Σ2 (ζ01 : Sub Σ0 Σ1) (ζ02 : Sub Σ0 Σ2) (ζ12 : Sub Σ1 Σ2) (a1 : AT Σ1) (a2 : AT Σ2) s1 s2,
          (forall (ι1 : SymInstance Σ1) (ι2 : SymInstance Σ2),
              syminstance_rel ζ12 ι1 ι2 ->
              forall s__sc : SCState Γ1,
                represents ι2 s2 s__sc ->
                represents ι1 s1 s__sc /\
                inst ι1 a1 = inst ι2 a2) ->
          outcome_result_geq ζ12 (symbolicstate_pathcondition s2) (f Σ1 ζ01 a1 s1) (f Σ2 ζ02 a2 s2).

      Definition dmut_bind' {Γ1 Γ2 Γ3 A B Σ0}
                 (ma : DynamicMutator Γ1 Γ2 A Σ0) (f : DynamicMutatorArrow' Γ2 Γ3 A B Σ0) : DynamicMutator Γ1 Γ3 B Σ0 :=
        fun (Σ1 : LCtx) (ζ01 : Sub Σ0 Σ1) (s1 : SymbolicState Γ1 Σ1) =>
          outcome_bind (ma Σ1 ζ01 s1) (fun r : DynamicMutatorResult Γ2 A Σ1 =>
          outcome_bind (f (dmutres_context r) (sub_comp ζ01 (dmutres_substitution r)) (dmutres_result_value r) (dmutres_result_state r))
                       (fun r2 : DynamicMutatorResult Γ3 B (dmutres_context r) => outcome_pure (cosubst_dmutres (dmutres_substitution r) r2))).

      Section WfBind.

        Transparent represents.

        Context
          {AT A BT B} {substB : Subst BT} {instB : Inst BT B} {instA : Inst AT A}
          {subA : Subst AT} {subLA : SubstLaws AT} {instLA : InstLaws AT A}.

        Lemma dmut_wf_bind' {Γ1 Γ2 Γ3 Σ0} (d : DynamicMutator Γ1 Γ2 AT Σ0) (wf_d : dmut_wf d)
              (f : DynamicMutatorArrow' Γ2 Γ3 AT BT Σ0)
              (f_wf : dmut_wf_arrow' f) :
          dmut_wf (dmut_bind' d f).
        Proof.
          (* unfold dmut_wf, dmut_bind', outcome_result_geq. *)
          (* intros * Heqs * P_dcl * Q_dcl * PQ QP. *)
          (* rewrite ?outcome_satisfy_bind. *)
          (* apply wf_d with ζ12. auto. *)
          (* - clear Q Q_dcl PQ QP. *)
          (*   revert f_wf P P_dcl. clear. intros f_wf P P_dcl. *)
          (*   unfold resultprop_downwards_closed. *)
          (*   intros [Σ2 ζ12 a2 [pc2 δ2 h2]] [Σ3 ζ13 a3 [pc3 δ3 h3]] [ζ23 Hgeqr]; cbn in *. *)
          (*   rewrite ?outcome_satisfy_bind; cbn. *)
          (*   apply (f_wf _ _ _ _ ζ23). *)
          (*   * intros ι2 ι3 rel23 s__sc. specialize (Hgeqr ι2 ι3 rel23 s__sc). *)
          (*     destruct s__sc as [δ h]; unfold represents in *; cbn in *. *)
          (*     intuition. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * intros [Σ4 ζ34 a4 [pc4 δ4 h4]] Hgeqpc34; *)
          (*       unfold resultprop_specialize; cbn in *. *)
          (*     apply P_dcl. exists (sub_id _). *)
          (*     intros ? ι4 <-. cbn. *)
          (*     specialize (Hgeqr (inst (inst ι4 ζ34) ζ23)). *)
          (*     specialize (Hgeqr (inst ι4 ζ34)). *)
          (*     specialize (Hgeqr eq_refl). *)
          (*     specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl). *)
          (*     revert Hgeqpc34. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc4. *)
          (*     revert Hgeqr. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc3. *)
          (*     rewrite ?inst_sub_id. *)
          (*     rewrite <- ?inst_subst. *)
          (*     rewrite <- sub_comp_assoc. *)
          (*     intuition. *)
          (*   * intros [Σ4 ζ34 a4 [pc4 δ4 h4]] Hgeqpc34; *)
          (*       unfold resultprop_specialize; cbn in *. *)
          (*     apply P_dcl. exists (sub_id _). *)
          (*     intros ? ι4 <-. cbn. *)
          (*     specialize (Hgeqr (inst (inst ι4 ζ34) ζ23)). *)
          (*     specialize (Hgeqr (inst ι4 ζ34)). *)
          (*     specialize (Hgeqr eq_refl). *)
          (*     specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl). *)
          (*     revert Hgeqpc34. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc4. *)
          (*     revert Hgeqr. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc3. *)
          (*     rewrite ?inst_sub_id. *)
          (*     rewrite <- ?inst_subst. *)
          (*     rewrite <- sub_comp_assoc. *)
          (*     intuition. *)
          (* - clear P P_dcl PQ QP. *)
          (*   revert f_wf Q Q_dcl. clear. intros f_wf Q Q_dcl. *)
          (*   unfold resultprop_downwards_closed. *)
          (*   intros [Σ3 ζ23 a3 [pc3 δ3 h3]] [Σ4 ζ24 a4 [pc4 δ4 h4]] [ζ34 Hgeqr]; cbn in *. *)
          (*   rewrite ?outcome_satisfy_bind; cbn. *)
          (*   apply (f_wf _ _ _ _ ζ34). *)
          (*   * revert Hgeqr. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros ι3. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros ι4. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros rel34. *)
          (*     unfold represents. cbn. *)
          (*     intros Hgeq [δ h]. cbn - [inst]. *)
          (*     intros. destruct_conjs. *)
          (*     intuition. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * intros [Σ5 ζ45 a5 [pc5 δ5 h5]]; unfold resultprop_specialize; cbn. *)
          (*     intros Hgeqpc45. apply Q_dcl. *)
          (*     exists (sub_id _). intros ? ι5 <-. cbn. *)
          (*     specialize (Hgeqr (inst (inst ι5 ζ45) ζ34)). *)
          (*     specialize (Hgeqr (inst ι5 ζ45)). *)
          (*     specialize (Hgeqr eq_refl). *)
          (*     specialize (Hgeqpc45 (inst ι5 ζ45) ι5 eq_refl). *)
          (*     revert Hgeqpc45. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc5. *)
          (*     revert Hgeqr. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc4. *)
          (*     rewrite ?inst_sub_id. *)
          (*     rewrite <- ?inst_subst. *)
          (*     rewrite <- sub_comp_assoc. *)
          (*     intuition. *)
          (*   * intros [Σ5 ζ45 a5 [pc5 δ5 h5]]; unfold resultprop_specialize; cbn. *)
          (*     intros Hgeqpc45. apply Q_dcl. *)
          (*     exists (sub_id _). intros ? ι5 <-. cbn. *)
          (*     specialize (Hgeqr (inst (inst ι5 ζ45) ζ34)). *)
          (*     specialize (Hgeqr (inst ι5 ζ45)). *)
          (*     specialize (Hgeqr eq_refl). *)
          (*     specialize (Hgeqpc45 (inst ι5 ζ45) ι5 eq_refl). *)
          (*     revert Hgeqpc45. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc5. *)
          (*     revert Hgeqr. *)
          (*     refine (@impl_forall_intro _ _ _ _); intros Hpc4. *)
          (*     rewrite ?inst_sub_id. *)
          (*     rewrite <- ?inst_subst. *)
          (*     rewrite <- sub_comp_assoc. *)
          (*     intuition. *)
          (* - intros [Σ3 ζ23 a3 [pc3 δ3 h3]] Hgeqpc23; unfold resultprop_specialize; cbn in *. *)
          (*   rewrite ?outcome_satisfy_bind; cbn. *)
          (*   eapply (f_wf _ _ _ _ (sub_id _)). *)
          (*   * intros ? ι3 <- s__sc. *)
          (*     rewrite inst_sub_id. *)
          (*     auto. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * intros [Σ4 ζ34 b4 [pc4 δ4 h4]]; cbn. *)
          (*     rewrite resultprop_specialize_id; cbn. *)
          (*     intros Hgeqpc34 Hp. apply PQ. *)
          (*     { unfold pc_geq; cbn. *)
          (*       intros ι2 ι4 rel24 Hpc4. *)
          (*       specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl Hpc4). *)
          (*       apply syminstance_rel_comp in rel24. *)
          (*       specialize (Hgeqpc23 ι2 (inst ι4 ζ34) rel24). *)
          (*       intuition. *)
          (*     } *)
          (*     unfold resultprop_specialize; cbn. *)
          (*     now rewrite <- sub_comp_assoc. *)
          (*   * intros r Hgeqpc34. *)
          (*     rewrite resultprop_specialize_id. *)
          (*     rewrite cosubst_dmutres_comp. *)
          (*     apply QP. clear PQ QP. unfold pc_geq in *. *)
          (*     destruct r as [Σ4 ζ34 b4 [pc4 δ4 h4]]; cbn in *. *)
          (*     intros ι2 ι4 rel24. *)
          (*     apply syminstance_rel_comp in rel24. *)
          (*     specialize (Hgeqpc23 ι2 (inst ι4 ζ34) rel24). *)
          (*     specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl). *)
          (*     intuition. *)
          (* - intros [Σ3 ζ23 a3 [pc3 δ3 h3]] Hgeqpc23; unfold resultprop_specialize; cbn in *. *)
          (*   rewrite ?outcome_satisfy_bind; cbn. *)
          (*   eapply (f_wf _ _ _ _ (sub_id _)). *)
          (*   * intros ? ι3 <- s__sc. *)
          (*     rewrite inst_sub_id. *)
          (*     auto. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * now apply resultprop_specialize_dcl. *)
          (*   * intros r Hgeqpc34. *)
          (*     rewrite resultprop_specialize_id. *)
          (*     rewrite cosubst_dmutres_comp. *)
          (*     apply QP. clear PQ QP. unfold pc_geq in *. *)
          (*     destruct r as [Σ4 ζ34 b4 [pc4 δ4 h4]]; cbn in *. *)
          (*     intros ι2 ι4 rel24. *)
          (*     apply syminstance_rel_comp in rel24. *)
          (*     specialize (Hgeqpc23 ι2 (inst ι4 ζ34) rel24). *)
          (*     specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl). *)
          (*     intuition. *)
          (*   * intros [Σ4 ζ34 b4 [pc4 δ4 h4]]; cbn. *)
          (*     rewrite resultprop_specialize_id; cbn. *)
          (*     intros Hgeqpc34 Hp. apply PQ. *)
          (*     { unfold pc_geq; cbn. *)
          (*       intros ι2 ι4 rel24 Hpc4. *)
          (*       specialize (Hgeqpc34 (inst ι4 ζ34) ι4 eq_refl Hpc4). *)
          (*       apply syminstance_rel_comp in rel24. *)
          (*       specialize (Hgeqpc23 ι2 (inst ι4 ζ34) rel24). *)
          (*       intuition. *)
          (*     } *)
          (*     unfold resultprop_specialize; cbn. *)
          (*     now rewrite <- sub_comp_assoc. *)
        Admitted.

      End WfBind.

    End WfExperiments.

    Lemma dmut_wp_sub {Γ1 Γ2 A Σ0} (d : DynamicMutator Γ1 Γ2 A Σ0)
          (POST : StateProperty Γ2 A Σ0) (s : SymbolicState Γ1 Σ0) Σ1 (ζ : Sub Σ0 Σ1) :
        dmut_wp d POST s ->
        dmut_wp (dmut_sub ζ d) (stateprop_specialize ζ POST) (subst ζ s).
    Proof.
      unfold dmut_sub, dmut_wp. intros * Hpost *.
      specialize (Hpost Σ2 (sub_comp ζ ζ1)).
      rewrite subst_sub_comp in Hpost. revert Hpost.
      apply outcome_satisfy_monotonic. clear. intros [Σ3 ζ3 r3 s3].
      unfold stateprop_specialize. now rewrite sub_comp_assoc.
    Qed.

    (* Definition dmut_wf'' {Γ1 Γ2 A AV Σ0} `{Inst A AV} (d : DynamicMutator Γ1 Γ2 A Σ0) : Prop := *)
    (*   forall (POST : StateProperty Γ2 A Σ0) (POST_dcl : stateprop_downwards_closed POST), *)
    (*     stateprop_downwards_closed *)
    (*       (fun Σ1 ζ1 _ => dmut_wp (dmut_sub ζ1 d) (stateprop_specialize ζ1 POST)). *)

    (* Lemma dmut_wf''_pure {Γ A Σ} `{SubstLaws A} (a : A Σ) : *)
    (*   dmut_wf'' (dmut_pure (Γ := Γ) a). *)
    (* Proof. *)
    (*   unfold dmut_wf''. intros. *)
    (*   unfold dmut_wp, dmut_sub, dmut_pure, stateprop_downwards_closed, stateprop_specialize; cbn; intros. *)
    (*   specialize (H2 _ (sub_comp ζ2 ζ0)). revert H2. *)
    (*   apply apply_sprop_dcl with (sub_id _); auto; *)
    (*     rewrite ?sub_comp_id_right, ?sub_comp_assoc; auto. *)
    (*   now rewrite subst_sub_id. *)
    (*   unfold state_geq in *. intros ? ? rel ?. *)
    (*   apply syminstance_rel_refl_inv in rel. subst ι1. *)
    (*   specialize (H1 _ (inst ι0 ζ0) eq_refl s__sc). intros rep. *)
    (*   apply (represents_rel eq_refl). unfold sub_comp. *)
    (*   rewrite inst_subst. apply H1. revert rep. *)
    (*   apply (represents_rel eq_refl). *)
    (* Qed. *)

    Lemma dmut_wf_assume_formula {Γ Σ} (f : Formula Σ) :
      dmut_wf (@dmut_assume_formula Γ Σ f).
    Proof.
      unfold dmut_assume_formula, dmut_wf.
      intros.
      destruct (try_solve_formula (subst ζ1 f)) eqn:?; cbn in H.
      - rewrite subst_sub_comp.
        pose proof (try_solve_formula_subst ζ2 _ Heqo) as ->.
        revert H. destruct b; cbn; auto.
        apply POST_dcl, dmutres_geq_syn_sem.
        exists ζ2. now rewrite sub_comp_id_left, sub_comp_id_right.
      - destruct (try_solve_formula_spec (subst (sub_comp ζ1 ζ2) f)).
        + destruct a; cbn; auto.
          apply dmutres_assume_formula_spec in H; auto. revert H.
          unfold resultprop_specialize. cbn.
          apply POST_dcl. exists ζ2.
          intros ? ? <- ? Hrep.
          apply (represents_rel eq_refl) in Hrep.
          rewrite inst_sub_id, sub_comp_id_right. split; auto.
          apply represents_assume_formula. split; auto.
          rewrite <- inst_subst, <- subst_sub_comp.
          now apply H0.
        + clear Heqo H0. cbn.
          apply dmutres_assume_formula_spec in H; auto.
          apply dmutres_assume_formula_spec.
          apply resultprop_specialize_dcl; auto.
          unfold resultprop_specialize; cbn.
          revert H. rewrite sub_comp_id_right.
          apply POST_dcl.
          apply dmutres_geq_syn_sem. exists ζ2.
          now rewrite sub_comp_id_left, subst_sub_comp, subst_symbolicstate_assume_formula.
    Qed.

    Lemma dmut_wf_produce {Γ Σ} (asn : Assertion Σ) :
      dmut_wf (@dmut_produce Γ Σ asn).
    Proof.
      induction asn; cbn.
      - apply dmut_wf_assume_formula.
      - admit.
      - apply dmut_wf_demonic_binary.
        + admit.
        + admit.
      - admit.
      - destruct (term_get_sum s) eqn:?.
        destruct s0; now apply dmut_wf_sub.
        apply dmut_wf_demonic_binary.
        + admit.
        + admit.
      - admit.
      - destruct (term_get_pair s) eqn:?.
        destruct p; now apply dmut_wf_sub.
        admit.
      - admit.
      - destruct (term_get_record s) eqn:?.
        now apply dmut_wf_sub.
        admit.
      - destruct (term_get_union s) eqn:?.
        destruct s0. admit.
        admit.
      - admit.
      - admit.
    Admitted.

    Opaque dmut_assume_formula.
    Opaque subst.
    Opaque sub_up1.
    Opaque sub_snoc.
    Opaque wk1.
    Opaque SubstEnv.

    Lemma dmut_wp_bind {Γ1 Γ2 Γ3 A BT Σ0 B} {substB : Subst BT} {instB : Inst BT B} (ma : DynamicMutator Γ1 Γ2 A Σ0)
          (f : forall Σ', Sub Σ0 Σ' -> A Σ' -> DynamicMutator Γ2 Γ3 BT Σ')
          (f_wf : forall Σ' ζ a, dmut_wf (f Σ' ζ a))
          (POST : StateProperty Γ3 BT Σ0) (POST_dcl : stateprop_downwards_closed POST) :
      forall s0 : SymbolicState Γ1 Σ0,
        dmut_wp (dmut_bind ma f) POST s0 <->
        dmut_wp ma (fun Σ1 ζ1 a1 => dmut_wp (f Σ1 ζ1 a1) (stateprop_specialize ζ1 POST)) s0.
    Proof.
      unfold DynamicMutator, dmut_bind, dmut_wp, dmut_wf in *; cbn; intros s0.
      split; intros H Σ1 ζ1; specialize (H Σ1 ζ1). revert H.
      - rewrite outcome_satisfy_bind. apply outcome_satisfy_monotonic.
        intros [Σ2 ζ2 a2 s2] H Σ3 ζ3.
        rewrite outcome_satisfy_bind in H.
        apply (f_wf Σ2 (sub_comp ζ1 ζ2) a2 Σ2 Σ3 (sub_id Σ2) ζ3) in H.
        + revert H. rewrite sub_comp_id_left.
          apply outcome_satisfy_monotonic.
          intros [Σ4 ζ4 b4 s4]. cbn.
          now rewrite <- sub_comp_assoc.
        + clear f_wf H.
          unfold resultprop_downwards_closed.
          intros [Σ4 ζ4 b4 s4] [Σ5 ζ5 b5 s5]. cbn - [dmutres_geq_sem].
          intros Hgeq. apply POST_dcl. rewrite <- ?sub_comp_assoc.
          revert Hgeq. apply dmutres_geq_sem_pre_comp.
      - rewrite outcome_satisfy_bind. revert H.
        apply outcome_satisfy_monotonic.
        intros [Σ2 ζ2 a2 s2] H. specialize (H Σ2 (sub_id _)).
        revert H. rewrite outcome_satisfy_bind, subst_sub_id.
        apply outcome_satisfy_monotonic.
        intros [Σ3 ζ3 b3 s3]. cbn.
        unfold stateprop_specialize.
        now rewrite sub_comp_id_left, sub_comp_assoc.
    Qed.

    Lemma dmut_wp_sub_bind {A BT B} {subB : Subst BT} {instB : Inst BT B} {Γ1 Γ2 Γ3  Σ0 Σ1} (ζ1 : Sub Σ0 Σ1)
          (ma : DynamicMutator Γ1 Γ2 A Σ0)
          (f : forall Σ', Sub Σ0 Σ' -> A Σ' -> DynamicMutator Γ2 Γ3 BT Σ')
          (f_wf : forall Σ' ζ a, dmut_wf (f Σ' ζ a))
          (POST : StateProperty Γ3 BT Σ1) (POST_dcl : stateprop_downwards_closed POST) :
      forall s0 : SymbolicState Γ1 Σ1,
        dmut_wp (dmut_sub ζ1 (dmut_bind ma f)) POST s0 <->
        dmut_wp
          (dmut_sub ζ1 ma)
          (fun Σ2 ζ2 a2 => dmut_wp (f Σ2 (sub_comp ζ1 ζ2) a2) (stateprop_specialize ζ2 POST))
          s0.
    Proof.
      unfold DynamicMutator, dmut_bind, dmut_sub, dmut_wp, dmut_wf in *; cbn; intros s0.
      split; intros H Σ2 ζ2; specialize (H Σ2 ζ2). revert H.
      - rewrite outcome_satisfy_bind. apply outcome_satisfy_monotonic.
        intros [Σ3 ζ3 a3 s3] H Σ4 ζ4.
        rewrite outcome_satisfy_bind in H.
        apply (f_wf Σ3 (sub_comp (sub_comp ζ1 ζ2) ζ3) a3 Σ3 Σ4 (sub_id Σ3) ζ4) in H.
        + revert H. rewrite sub_comp_id_left, sub_comp_assoc.
          apply outcome_satisfy_monotonic.
          intros [Σ5 ζ5 b5 s5]. cbn.
          now rewrite <- sub_comp_assoc.
        + revert POST_dcl. clear. intros.
          unfold resultprop_downwards_closed.
          intros [Σ4 ζ4 b4 s4] [Σ5 ζ5 b5 s5] Hgeq.
          cbn. apply POST_dcl. rewrite <- ?sub_comp_assoc.
          revert Hgeq. apply dmutres_geq_sem_pre_comp.
      - rewrite outcome_satisfy_bind. revert H.
        apply outcome_satisfy_monotonic.
        intros [Σ3 ζ3 a3 s3] H. specialize (H Σ3 (sub_id _)).
        revert H. rewrite outcome_satisfy_bind, subst_sub_id, sub_comp_assoc.
        apply outcome_satisfy_monotonic.
        intros [Σ4 ζ4 b4 s4]. cbn.
        unfold stateprop_specialize.
        now rewrite sub_comp_id_left, sub_comp_assoc.
    Qed.

    Lemma dmut_wp_fresh {Γ Σ0 AT A x τ} `{Subst AT, Inst AT A}
          (d : DynamicMutator Γ Γ AT (Σ0 ▻ (x,τ))%ctx)
          (POST : StateProperty Γ AT Σ0)
          (POST_dcl : stateprop_downwards_closed POST)
          (s : SymbolicState Γ Σ0) (wfd : dmut_wf d) :
      dmut_wp (dmut_fresh (x,τ) d) POST s <->
      dmut_wp d (stateprop_specialize sub_wk1 POST) (subst sub_wk1 s).
    Proof.
      unfold dmut_wp, dmut_fresh; cbn; split; intros HYP ? ?.
      - dependent elimination ζ1 as [@env_snoc Σ0 ζ1 _ v]; cbn in v.
        rewrite <- subst_sub_comp, sub_comp_wk1_tail; cbn.
        specialize (HYP Σ1 ζ1).
        rewrite outcome_satisfy_map in HYP; cbn in *.
        apply (@wfd _ Σ1 _ (env_snoc (sub_id _) (_,τ) v)) in HYP; clear wfd.
        + change (wk1 (subst ζ1 s)) with (subst (sub_wk1 (b:=(x,τ))) (subst ζ1 s)) in HYP.
          rewrite <- subst_sub_comp, <- sub_snoc_comp, sub_comp_id_right, sub_comp_wk1_tail in HYP.
          cbn in HYP. rewrite subst_sub_id in HYP. revert HYP.
          apply outcome_satisfy_monotonic.
          intros [Σ2 ζ2 r2]. cbn. clear.
          intuition.
          rewrite <- (sub_comp_assoc sub_wk1), sub_comp_wk1_tail in H; cbn in H.
          rewrite sub_comp_id_left in H.
          unfold stateprop_specialize.
          now rewrite <- sub_comp_assoc, sub_comp_wk1_tail.
        + revert POST_dcl. clear. intros.
          unfold resultprop_downwards_closed.
          intros [Σ2 ζ2 a2 s2] [Σ3 ζ3 a3 s3] Hgeq.
          cbn. apply POST_dcl. rewrite <- ?sub_comp_assoc.
          revert Hgeq. apply dmutres_geq_sem_pre_comp.
      - rewrite outcome_satisfy_map.
        specialize (HYP (Σ1 ▻ (x,τ)) (sub_up1 ζ1)).
        rewrite <- subst_sub_comp, sub_comp_wk1_comm in HYP.
        change (wk1 (b := (x,τ)) (subst ζ1 s)) with (subst (sub_wk1 (b := (x,τ))) (subst ζ1 s)).
        rewrite <- subst_sub_comp. revert HYP.
        apply outcome_satisfy_monotonic.
        intros [Σ2 ζ2 r2]. clear.
        dependent elimination ζ2 as [@env_snoc Σ1 ζ2 _ t].
        unfold stateprop_specialize.
        now rewrite <- ?sub_comp_assoc, <- sub_comp_wk1_comm.
    Qed.

    Lemma dmut_wp_sub_fresh {Γ Σ0 Σ1 AT A x τ} `{Subst AT, Inst AT A}
          (ζ1 : Sub Σ0 Σ1)
          (d : DynamicMutator Γ Γ AT (Σ0 ▻ (x,τ))%ctx)
          (POST : StateProperty Γ AT Σ1)
          (POST_dcl : stateprop_downwards_closed POST)
          (s : SymbolicState Γ Σ1) (wfd : dmut_wf d) :
      dmut_wp (dmut_sub ζ1 (dmut_fresh (x,τ) d)) POST s <->
      dmut_wp (dmut_sub (sub_up1 ζ1) d) (stateprop_specialize sub_wk1 POST) (subst sub_wk1 s).
    Proof.
      unfold dmut_wp, dmut_sub, dmut_fresh; cbn; split; intros HYP Σ2 ζ2.
      - dependent elimination ζ2 as [@env_snoc Σ1 ζ2 _ v]; cbn in v.
        rewrite <- subst_sub_comp, sub_comp_wk1_tail; cbn.
        specialize (HYP Σ2 ζ2).
        rewrite outcome_satisfy_map in HYP; cbn in *.
        apply (@wfd _ Σ2 _ (env_snoc (sub_id _) (_,τ) v)) in HYP; clear wfd.
        + change (wk1 (subst ζ2 s)) with (subst (sub_wk1 (b:=(x,τ))) (subst ζ2 s)) in HYP.
          rewrite <- subst_sub_comp, <- sub_snoc_comp, sub_comp_id_right, sub_comp_wk1_tail in HYP.
          cbn in HYP. rewrite subst_sub_id in HYP.
          rewrite <- sub_snoc_comp. revert HYP.
          apply outcome_satisfy_monotonic.
          intros [Σ3 ζ3 r3]. cbn. clear.
          intuition.
          rewrite <- (sub_comp_assoc sub_wk1), sub_comp_wk1_tail in H; cbn in H.
          rewrite sub_comp_id_left in H.
          unfold stateprop_specialize.
          now rewrite <- sub_comp_assoc, sub_comp_wk1_tail.
        + revert POST_dcl. clear. intros.
          unfold resultprop_downwards_closed.
          intros [Σ3 ζ3 a3 s3] [Σ4 ζ4 a4 s4] Hgeq.
          cbn. apply POST_dcl. rewrite <- ?sub_comp_assoc.
          revert Hgeq. apply dmutres_geq_sem_pre_comp.
      - rewrite outcome_satisfy_map.
        specialize (HYP (Σ2 ▻ (x,τ)) (sub_up1 ζ2)).
        rewrite <- subst_sub_comp, sub_comp_wk1_comm in HYP.
        change (wk1 (b := (x,τ)) (subst ζ2 s)) with (subst (sub_wk1 (b := (x,τ))) (subst ζ2 s)).
        rewrite sub_up_comp, <- subst_sub_comp.
        revert HYP. apply outcome_satisfy_monotonic.
        intros [Σ3 ζ3 r3]. clear.
        dependent elimination ζ3 as [@env_snoc Σ2 ζ3 _ t].
        unfold stateprop_specialize.
        now rewrite <- ?sub_comp_assoc, <- sub_comp_wk1_comm.
    Qed.

    Lemma dmut_bind_sound {Γ1 Γ2 Γ3 Σ0 AT A BT B}
      `{Subst AT, Inst AT A, InstLaws BT B} (ι0 : SymInstance Σ0)
      (dma : DynamicMutator Γ1 Γ2 AT Σ0) (wfdm : dmut_wf dma)
      (sma : SCMut Γ1 Γ2 A)
      (dmf : forall Σ1, Sub Σ0 Σ1 -> AT Σ1 -> DynamicMutator Γ2 Γ3 BT Σ1)
      (dmf_wf : forall Σ1 ζ a, dmut_wf (dmf Σ1 ζ a))
      (smf : A -> SCMut Γ2 Γ3 B) :
      box approximates ι0 dma sma ->
      (forall Σ1 (ζ1 : Sub Σ0 Σ1) (a1 : AT Σ1) (ι1 : SymInstance Σ1),
          syminstance_rel ζ1 ι0 ι1 ->
          box approximates ι1 (dmf Σ1 ζ1 a1) (smf (inst ι1 a1))) ->
      box approximates ι0 (dmut_bind dma dmf) (scmut_bind sma smf).
    Proof.
      intros H__a H__f.
      intros Σ1 ζ1 ι1 relι1 s__sym1 s__sc1 H__rep POST H__wp.
      apply scmut_wp_bind.
      apply dmut_wp_sub_bind in H__wp; auto using stateprop_lift_dcl.
      specialize (H__a Σ1 ζ1 ι1 relι1).
      apply H__a with s__sym1. assumption.
      revert H__wp. apply dmut_wp_monotonic.
      intros Σ2 ζ2 a2 s__sym2 H__wp ι2 relι2 s__sc2 s__rep2.
      specialize (H__f Σ2 (sub_comp ζ1 ζ2) a2 ι2).
      inster H__f by eapply syminstance_rel_trans; eauto.
      apply approximates_proj in H__f. eapply H__f. eassumption.
      revert H__wp. apply dmut_wp_monotonic.
      intros Σ3 ζ3 b3 s__sym3 H__post ι3 relι3 s__sc3 s__rep3.
      apply H__post. apply (syminstance_rel_trans relι2 relι3). assumption.
    Qed.

    Lemma dmut_fresh_sound {Γ Σ ς τ} (ι : SymInstance Σ)
          (dm : DynamicMutator Γ Γ Unit (Σ ▻ (ς,τ))) (wfdm : dmut_wf dm)
          (sm : Lit τ -> SCMut Γ Γ unit) :
      (forall v, box approximates (env_snoc ι _ v) dm (sm v)) ->
      box approximates ι
        (dmut_fresh (ς,τ) dm)
        (scmut_demonic sm).
    Proof.
      intros HYP. unfold box, approximates.
      intros ? ? ? ? ? ? H__state POST H.
      apply scmut_wp_demonic. intros v.
      specialize (HYP v (Σ1 ▻ (ς,τ)) (sub_up1 ζ1) (env_snoc ι1 (ς,τ) v)).
      inster HYP by apply syminstance_rel_up; auto.
      unfold approximates in HYP.
      apply (HYP (subst (sub_wk1) s__sym)). clear HYP.
      - revert H__state. apply represents_rel, syminstance_rel_wk1.
      - apply (@dmut_wp_sub_fresh Γ Σ Σ1 Unit _ ς τ SubstUnit InstUnit) in H.
        + revert H; clear.
          apply dmut_wp_monotonic; cbn; intros ? ? []; intros.
          dependent elimination ζ as [@env_snoc Σ0 ζ _ t].
          unfold stateprop_specialize in H.
          rewrite sub_comp_wk1_tail in H; cbn in *.
          intros ι2 H0 s2 H1.
          apply H.
          * now apply syminstance_rel_snoc in H0.
          * assumption.
        + apply stateprop_lift_dcl.
        + assumption.
    Qed.

    Lemma dmut_produce_sound {Γ Σ} (asn : Assertion Σ) (ι : SymInstance Σ) :
      box approximates
        (Γ1 := Γ) (Γ2 := Γ) ι
        (dmut_produce asn)
        (scmut_produce ι asn).
    Proof.
      induction asn; cbn.
      - apply dmut_assume_formula_sound.
      - apply dmut_produce_chunk_sound.
      - apply approximates_demonic_binary.
        + unfold dmut_bind_right.
          eapply dmut_bind_sound.
          apply dmut_wf_assume_formula.
          intros. apply dmut_wf_sub, dmut_wf_produce.
          apply dmut_assume_formula_sound.
          intros.
          eapply approximates_sub; eauto.
        + eapply dmut_bind_sound.
          apply dmut_wf_assume_formula.
          intros. apply dmut_wf_sub, dmut_wf_produce.
          apply dmut_assume_formula_sound.
          intros.
          eapply approximates_sub; eauto.
      - admit.
      - admit.
      - admit.
      - admit.
      - admit.
      - admit.
      - admit.
      - intros. apply dmut_bind_sound. admit. admit.
        apply IHasn1. intros.
        eapply approximates_sub; eauto.
      - apply dmut_fresh_sound.
        + admit.
        + intros. apply IHasn.
    Admitted.

    Opaque dmut_wp.
    Opaque scmut_wp.

    Section Leftovers.

      Context `{HL: IHeaplet L} {SLL: ISepLogicLaws L}.

      Definition interpret_heap {Σ} (ι : SymInstance Σ) (h : SymbolicHeap Σ) : L :=
        List.fold_right (fun c h => ASS.inst_chunk ι c ∧ h) ltrue h.

      Transparent subst SubstEnv.
      Lemma subst_lookup {Γ Σ Σ' x σ} (xInΓ : (x ∶ σ)%ctx ∈ Γ) (ζ : Sub Σ Σ') (δ : SymbolicLocalStore Γ Σ) :
        (subst ζ (δ ‼ x)%exp = (subst ζ δ ‼ x)%exp).
      Proof.
        unfold subst at 2, subst_localstore, SubstEnv.
        now rewrite env_lookup_map.
      Qed.

      Lemma subst_symboliceval {Γ τ Σ Σ'} (e : Exp Γ τ) (ζ : Sub Σ Σ') (δ : SymbolicLocalStore Γ Σ) :
        subst (T := fun Σ => Term Σ _) ζ (symbolic_eval_exp δ e) = symbolic_eval_exp (subst ζ δ) e.
      Proof.
        induction e; cbn; f_equal; auto.
        { now rewrite (subst_lookup xInΓ). }
        all: induction es; cbn in *; destruct_conjs; f_equal; auto.
      Qed.

      Transparent inst instantiate_env.

      Lemma eval_exp_inst {Γ Σ τ} (ι : SymInstance Σ) (δΓΣ : SymbolicLocalStore Γ Σ) (e : Exp Γ τ) :
        eval e (inst ι δΓΣ) = inst ι (symbolic_eval_exp δΓΣ e).
      Proof.
        induction e; cbn; repeat f_equal; auto.
        { unfold inst; cbn. now rewrite env_lookup_map. }
        2: {
          induction es as [|eb n es IHes]; cbn in *.
          { reflexivity. }
          { destruct X as [-> Heqs].
            change (inst_term ?ι ?t) with (inst ι t).
            destruct (inst ι (symbolic_eval_exp δΓΣ eb));
              cbn; f_equal; auto.
          }
        }
        all: induction es; cbn in *; destruct_conjs; f_equal; auto.
      Qed.

    End Leftovers.

  End DynMutV1Soundness.

End Soundness.

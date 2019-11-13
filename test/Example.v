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
     Program.Equality
     Program.Tactics
     Strings.String
     ZArith.ZArith
     micromega.Lia.

From MicroSail Require Import
     WLP.Spec
     Syntax.

Set Implicit Arguments.
Import CtxNotations.
Import EnvNotations.
Open Scope string_scope.
Open Scope Z_scope.
Open Scope ctx_scope.

Inductive Enums : Set :=
| ordering.

Inductive Ordering : Set :=
| LT
| EQ
| GT.

Module ExampleTypeKit <: TypeKit.

  Definition 𝑬 : Set := Enums.
  Definition 𝑻 : Set := Empty_set.
  Definition 𝑹 : Set := Empty_set.
  Definition 𝑿 : Set := string.
  Definition 𝑿_eq_dec := string_dec.

End ExampleTypeKit.
Module ExampleTypes := Types ExampleTypeKit.
Import ExampleTypes.

Notation "x ∶ τ" := (pair x τ) (at level 90, no associativity) : ctx_scope.
Notation "[ x ]" := (ctx_snoc ctx_nil x) : ctx_scope.
Notation "[ x , .. , z ]" := (ctx_snoc .. (ctx_snoc ctx_nil x) .. z) : ctx_scope.

Module ExampleTermKit <: (TermKit ExampleTypeKit).
  Module TY := ExampleTypes.

  (* Names of union data constructors. *)
  Definition 𝑬𝑲 (E : 𝑬) : Set :=
    match E with
    | ordering => Ordering
    end.

  Definition 𝑲 (T : 𝑻) : Set := match T with end.
  Definition 𝑲_Ty (T : 𝑻) : 𝑲 T -> Ty := match T with end.
  Definition 𝑹𝑭  : Set := Empty_set.
  Definition 𝑹𝑭_Ty (R : 𝑹) : Ctx (𝑹𝑭 * Ty) := match R with end.

  (* Names of functions. *)
  Inductive Fun : Ctx (𝑿 * Ty) -> Ty -> Set :=
  | swappair   : Fun
                   [ "x" ∶ ty_prod ty_bool ty_int ]
                   (ty_prod ty_int ty_bool)
  | swaptuple  : Fun
                   [ "x" ∶ ty_tuple [ ty_bool, ty_int ] ]
                   (ty_tuple [ ty_int , ty_bool ])
  | cycletuple : Fun
                   [ "x" ∶ ty_tuple [ ty_bool, ty_int, ty_string ]]
                   (ty_tuple [ ty_int, ty_string, ty_bool ])
  | abs : Fun [ "x" ∶ ty_int ] ty_int
  | gcd : Fun [ "p" ∶ ty_int, "q" ∶ ty_int ] ty_int
  | gcdpos : Fun [ "p" ∶ ty_int, "q" ∶ ty_int ] ty_int
  | gcdcompare : Fun [ "p" ∶ ty_int, "q" ∶ ty_int ] ty_int
  | compare : Fun [ "x" ∶ ty_int, "y" ∶ ty_int ] (ty_enum ordering)
  .

  Definition 𝑭  : Ctx (𝑿 * Ty) -> Ty -> Set := Fun.

End ExampleTermKit.
Module ExampleTerms := Terms ExampleTypeKit ExampleTermKit.
Import ExampleTerms.
Import NameResolution.

Notation "[ x , .. , z ]" :=
  (tuplepat_snoc .. (tuplepat_snoc tuplepat_nil x) .. z) : pat_scope.
Notation "[ x , .. , z ]" :=
  (env_snoc .. (env_snoc env_nil _ x) .. _ z) : exp_scope.

Notation "e1 * e2" := (exp_times e1 e2) : exp_scope.
Notation "e1 - e2" := (exp_minus e1 e2) : exp_scope.
Notation "e1 < e2" := (exp_lt e1 e2) : exp_scope.
Notation "e1 > e2" := (exp_gt e1 e2) : exp_scope.
Notation "e1 <= e2" := (exp_le e1 e2) : exp_scope.
Notation "e1 = e2" := (exp_eq e1 e2) : exp_scope.
Notation "'lit_int' l" := (exp_lit _ ty_int l) (at level 1, no associativity) : exp_scope.
Notation "'lit_unit'" := (exp_lit _ ty_unit tt) (at level 1, no associativity) : exp_scope.

Local Coercion stmexp := @stm_exp.

Module ExampleProgramKit <: (ProgramKit ExampleTypeKit ExampleTermKit).
  Module TM := ExampleTerms.

  Local Open Scope exp_scope.

  Definition Pi {Δ τ} (f : Fun Δ τ) : Stm Δ τ :=
    match f in Fun Δ τ return Stm Δ τ with
    | swappair =>
      stm_bind
        (exp_var "x")
        (fun x : Lit (ty_prod ty_bool ty_int) =>
           let (l , r) := x in exp_lit _ (ty_prod ty_int ty_bool) (r , l)
        )
      (* stm_match_pair (exp_var "x") "l" "r" (exp_pair (exp_var "r") (exp_var "l")) *)
    | swaptuple => stm_match_tuple (exp_var "x") ["l", "r"] (exp_tuple [exp_var "r", exp_var "l"])
    | cycletuple => stm_match_tuple
                      (exp_var "x")
                      ["u", "v", "w"]
                      (exp_tuple [exp_var "v", exp_var "w", exp_var "u"])
    | abs =>
      stm_if
        (lit_int (0%Z) <= exp_var "x")
        (exp_var "x")
        (exp_neg (exp_var "x"))
    | gcdcompare =>
      stm_bind
        (stm_app compare [exp_var "p", exp_var "q"])
        (fun K =>
           match K with
           | LT => stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p")) ("q" , ty_int) (exp_var "q" - exp_var "p"))
           | EQ => stm_exp (exp_var "p")
           | GT => stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p" - exp_var "q")) ("q" , ty_int) (exp_var "q"))
           end)
      (* stm_let "ord" (ty_enum ordering) *)
      (*   (stm_app compare [exp_var "p", exp_var "q"]) *)
      (*   (stm_match_enum ordering (exp_var "ord") *)
      (*      (fun K => *)
      (*         match K with *)
      (*         | LT => stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p")) ("q" , ty_int) (exp_var "q" - exp_var "p")) *)
      (*         | EQ => stm_exp (exp_var "p") *)
      (*         | GT => stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p" - exp_var "q")) ("q" , ty_int) (exp_var "q")) *)
      (*         end)) *)
    | gcd =>
      stm_let "p'" ty_int (stm_app abs [exp_var "p"])
      (stm_let "q'" ty_int (stm_app abs [exp_var "q"])
        (stm_app gcdpos [exp_var "p'", exp_var "q'"]))
    | gcdpos =>
      stm_if
        (exp_var "p" = exp_var "q")
        (exp_var "p")
        (stm_if
           (exp_var "p" < exp_var "q")
           (stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p")) ("q" , ty_int) (exp_var "q" - exp_var "p")))
           (stm_app gcd (env_snoc (env_snoc env_nil ("p" , ty_int) (exp_var "p" - exp_var "q")) ("q" , ty_int) (exp_var "q")))
        )
    | compare =>
      stm_if (exp_var "x" < exp_var "y")
        (stm_lit (ty_enum ordering) LT)
      (stm_if (exp_var "x" = exp_var "y")
        (stm_lit (ty_enum ordering) EQ)
      (stm_if (exp_var "x" > exp_var "y")
        (stm_lit (ty_enum ordering) GT)
        (stm_exit (ty_enum ordering) "compare")))
    end.

End ExampleProgramKit.
Import ExampleProgramKit.

(******************************************************************************)

Module ExampleContractKit <: (ContractKit ExampleTypeKit ExampleTermKit ExampleProgramKit).

  Definition CEnv : ContractEnv :=
    fun σs τ f =>
      match f with
      | abs =>
        Some {| contract_pre_condition := fun _ => True;
                contract_post_condition := fun (v : Lit ty_int)
                                               (δ : Env' Lit [ "x" ∶ ty_int ]) =>
                                             v = Z.abs (δ ! "x")
             |}
      | compare =>
        Some {| contract_pre_condition := fun _ => True;
                contract_post_condition := fun (K : Lit (ty_enum ordering))
                                               (δ : Env' Lit [ "x" ∶ ty_int , "y" ∶ ty_int ]) =>
                                             match K with
                                             | LT => δ ! "x" <= δ ! "y"
                                             | EQ => δ ! "x"  = δ ! "y"
                                             | GT => δ ! "x" >= δ ! "y"
                                             end
             |}
      | gcdpos =>
        Some {| contract_pre_condition := fun (δ : Env' Lit [ "p" ∶ ty_int , "q" ∶ ty_int ]) =>
                                            (δ ! "p") >= 0 /\ (δ ! "q" >= 0);
                contract_post_condition := fun (r : Lit ty_int)
                                               (δ : Env' Lit [ "p" ∶ ty_int , "q" ∶ ty_int ]) =>
                                             r = Z.gcd (δ ! "p") (δ ! "q")
             |}
      | gcd =>
        Some {| contract_pre_condition := fun (δ : Env' Lit [ "p" ∶ ty_int , "q" ∶ ty_int ]) => True;
                contract_post_condition := fun (r : Lit ty_int)
                                               (δ : Env' Lit [ "p" ∶ ty_int , "q" ∶ ty_int ]) =>
                                             r = Z.gcd (δ ! "p") (δ ! "q")
             |}
      | _ => Some {| contract_pre_condition := fun _ => True;
                     contract_post_condition := fun _ _ => True
                  |}
      end.

End ExampleContractKit.
Import ExampleContractKit.

Module ExampleWLP := WLP ExampleTypeKit ExampleTermKit ExampleProgramKit ExampleContractKit.
Import ExampleWLP.

Definition ValidContract {Γ τ} (c : Contract Γ τ) (s : Stm Γ τ) : Prop :=
  forall δ, contract_pre_condition c δ -> WLP s (contract_post_condition c) δ.

Definition ValidContractEnv (cenv : ContractEnv) : Prop :=
  forall σs σ (f : 𝑭 σs σ),
    match cenv σs σ f with
    | Some c => ValidContract c (Pi f)
    | None => True
    end.

Lemma gcd_sub_diag_l (n m : Z) : Z.gcd (n - m) m = Z.gcd n m.
Proof. now rewrite Z.gcd_comm, Z.gcd_sub_diag_r, Z.gcd_comm. Qed.

Ltac validate_destr :=
  match goal with
  | [ |- _ -> _ ]  => intro
  | [ |- True ]  => constructor
  | [ H: True |- _ ] => clear H
  | [ H: False |- _ ] => destruct H
  | [ H: Env _ (ctx_snoc _ _) |- _ ] => dependent destruction H
  | [ H: Env _ ctx_nil |- _ ] => dependent destruction H
  | [ H: Env' _ (ctx_snoc _ _) |- _ ] => dependent destruction H
  | [ H: Env' _ ctx_nil |- _ ] => dependent destruction H
  end.

Ltac validate_simpl :=
  repeat
    (cbn in *; repeat validate_destr; destruct_conjs; subst;
     rewrite ?Z.eqb_eq, ?Z.eqb_neq, ?Z.leb_gt, ?Z.ltb_ge, ?Z.ltb_lt, ?Z.leb_le, ?Z.gtb_ltb,
       ?Z.gcd_diag, ?Z.gcd_abs_l, ?Z.gcd_abs_r, ?Z.gcd_sub_diag_r, ?gcd_sub_diag_l in *).

Ltac validate_case :=
  match goal with
  | [ |- match ?e with _ => _ end _ _ ] =>
    case_eq e
  | [ |- WLP match ?e with _ => _ end _ _ ] =>
    case_eq e
  end.

Ltac validate_solve :=
  repeat
    (validate_simpl; intuition;
     try lia;
     try validate_case).

Lemma validCEnv : ValidContractEnv CEnv.
Proof. intros σs τ [] δ; validate_solve. Qed.

(* Print Assumptions validCEnv. *)

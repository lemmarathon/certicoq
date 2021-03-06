(** An alternative definition of wndEval that is extensionally
*** equivalent for well-formed programs
**)
Require Import FunInd.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.Relations.Relation_Operators.
Require Import Coq.Relations.Operators_Properties.
Require Import Coq.Setoids.Setoid.
Require Import Common.Common.
Require Import L1g.compile.
Require Import L1g.term.
Require Import L1g.program.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.

(*** alrernative non-deterministic small step evaluation relation ***)
Section Env.
Variable p: environ Term.
Inductive awndEval : Term -> Term -> Prop :=
(** contraction steps **)
| aConst: forall (s:string) (t:Term),
         LookupDfn s p t -> awndEval (TConst s) t
| aBeta: forall (nm:name) (ty bod arg:Term) (args:Terms),
           awndEval (TApp (TLambda nm ty bod) arg args)
                   (whBetaStep bod arg args)
     (* note: [instantiate] is total *)
| aLetIn: forall (nm:name) (dfn ty bod:Term),
            awndEval (TLetIn nm dfn ty bod) (instantiate dfn 0 bod)
     (* Case argument must be in Canonical form *)
     (* np is the number of parameters of the datatype *)
| aCase: forall (ml: inductive * nat) (ty s mch:Term)
                 (args ts:Terms) (brs:Brs) (n:nat),
            canonicalP mch = Some (n, args) ->
            tskipn (snd ml) args = Some ts ->
            whCaseStep n ts brs = Some s ->
            awndEval (TCase ml ty mch brs) s
| aFix: forall (dts:Defs) (m:nat) (arg:Term) (args:Terms)
               (x:Term) (ix:nat),
          (** ix is index of recursive argument **)
          dnthBody m dts = Some (x, ix) ->
          awndEval (TApp (TFix dts m) arg args)
                  (pre_whFixStep x dts (tcons arg args))
| aProof: forall t, awndEval (TProof t) t
(** congruence steps **)
(** no xi rules: sLambdaR, sProdR, sLetInR,
 *** no congruence on Case branches or Fix ***)
| aAppFn:  forall (t r arg:Term) (args:Terms),
              awndEval t r ->
              awndEval (mkApp t (tcons arg args)) (mkApp r (tcons arg args))
| aAppArgs: forall (t arg brg:Term) (args brgs:Terms),
              awndEvals (tcons arg args) (tcons brg brgs) ->
              awndEval (TApp t arg args) (TApp t brg brgs)
| aProdTy:  forall (nm:name) (t1 t2 bod:Term),
              awndEval t1 t2 ->
              awndEval (TProd nm t1 bod) (TProd nm t2 bod)
| aLamTy:   forall (nm:name) (t1 t2 bod:Term),
              awndEval t1 t2 ->
              awndEval (TLambda nm t1 bod) (TLambda nm t2 bod)
| aLetInTy: forall (nm:name) (t1 t2 d bod:Term),
              awndEval t1 t2 ->
              awndEval (TLetIn nm d t1 bod) (TLetIn nm d t2 bod)
| aLetInDef:forall (nm:name) (t d1 d2 bod:Term),
              awndEval d1 d2 ->
              awndEval (TLetIn nm d1 t bod) (TLetIn nm d2 t bod)
| aCaseTy:  forall (ml: inductive * nat) (ty uy mch:Term) (brs:Brs),
              awndEval ty uy ->
              awndEval (TCase ml ty mch brs) (TCase ml uy mch brs)
| aCaseArg: forall (ml: inductive * nat) (ty mch can:Term) (brs:Brs),
              awndEval mch can ->
              awndEval (TCase ml ty mch brs) (TCase ml ty can brs)
with awndEvals : Terms -> Terms -> Prop :=
     | aaHd: forall (t r:Term) (ts:Terms), 
               awndEval t r ->
               awndEvals (tcons t ts) (tcons r ts)
     | aaTl: forall (t:Term) (ts ss:Terms),
               awndEvals ts ss ->
               awndEvals (tcons t ts) (tcons t ss).
Hint Constructors awndEval awndEvals.
Scheme awndEval1_ind := Induction for awndEval Sort Prop
     with awndEvals1_ind := Induction for awndEvals Sort Prop.
Combined Scheme awndEvalEvals_ind from awndEval1_ind, awndEvals1_ind.

Definition no_awnd_step (t:Term) : Prop :=
  no_step awndEval t.
Definition no_awnds_step (ts:Terms) : Prop :=
  no_step awndEvals ts.

Lemma awndEval_tappendl:
  forall bs cs, awndEvals bs cs ->
  forall ds, awndEvals (tappend bs ds) (tappend cs ds).
Proof.
  induction 1; intros.
  - constructor. assumption.
  - simpl. apply aaTl. apply IHawndEvals.
Qed.

Lemma awndEval_tappendr:
  forall bs cs, awndEvals bs cs ->
  forall ds, awndEvals (tappend ds bs) (tappend ds cs).
Proof.
  intros bs cs h ds. induction ds; simpl.
  - assumption.
  - apply aaTl. apply IHds.
Qed.

Lemma awndEval_Lam_inv:
  forall nm tp bod s,
    awndEval (TLambda nm tp bod) s ->
    exists tp', awndEval tp tp' /\ s = (TLambda nm tp' bod).
Proof.
  intros nm tp bod s h. inversion_Clear h.
  - destruct (mkApp_isApp t arg args) as [x0 [x1 [x2 k]]].
    rewrite k in H. discriminate.
  - exists t2. split; [assumption | reflexivity].
Qed.

Lemma awndEval_Prod_inv:
  forall nm tp bod s,
    awndEval (TProd nm tp bod) s ->
    exists tp', awndEval tp tp' /\ s = (TProd nm tp' bod).
Proof.
  intros nm tp bod s h. inversion_Clear h.
  - destruct (mkApp_isApp t arg args) as [x0 [x1 [x2 k]]].
    rewrite k in H. discriminate.
  - exists t2. split; [assumption | reflexivity].
Qed.

Lemma WFapp_mkProof_WFapp:
  forall t, WFapp (mkProof t) -> WFapp t.
Proof. 
  intros t. functional induction (mkProof t); intros.
  - assumption.
  - inversion_Clear H. assumption.
Qed.

Lemma awndEval_pres_WFapp:
  WFaEnv p ->
  (forall t s, awndEval t s -> WFapp t -> WFapp s) /\
  (forall ts ss, awndEvals ts ss -> WFapps ts -> WFapps ss).
Proof.
  intros hp.
  apply awndEvalEvals_ind; intros; try assumption;
  try (solve [inversion_Clear H0; constructor; intuition]).
  - unfold LookupDfn in l. assert (j:= Lookup_pres_WFapp hp l).
    inversion j. assumption.
  - inversion_Clear H. inversion_Clear H4.
    apply whBetaStep_pres_WFapp; assumption.
  - inversion_Clear H. apply instantiate_pres_WFapp; assumption.
  - inversion_Clear H.
    refine (whCaseStep_pres_WFapp _ _ _ e1). assumption.
    refine (tskipn_pres_WFapp _ _ e0).
    refine (canonicalP_pres_WFapp _ e). assumption.
  - inversion_Clear H. inversion_Clear H4.
    assert (j:= dnthBody_pres_WFapp H0 m).
    apply pre_whFixStep_pres_WFapp; try assumption.
    + eapply j. eassumption.
    + constructor; assumption.
  - inversion_Clear H. assumption.
  - destruct (WFapp_mkApp_WFapp H0 _ _ eq_refl). inversion_Clear H2.
    apply mkApp_pres_WFapp.
    + constructor; assumption.
    + intuition.
  - inversion_Clear H0. 
    assert (j: WFapps (tcons arg args)).
    { constructor; assumption. }
    specialize (H j). inversion_Clear H.
    constructor; assumption.
Qed.


(** reflexive-transitive closure of wndEval **)
Inductive awndEvalRTC: Term -> Term -> Prop :=
(** | wERTCrfl: forall t, WNorm t -> awndEvalRTC p t t ??? **)
| awERTCrfl: forall t, awndEvalRTC t t
| awERTCstep: forall t s, awndEval t s -> awndEvalRTC t s
| awERTCtrn: forall t s u,
              awndEvalRTC t s -> awndEvalRTC s u -> awndEvalRTC t u.
Inductive awndEvalsRTC : Terms -> Terms -> Prop :=
(** | wEsRTCrfl: forall ts, WNorms ts -> wndEvalsRTC p ts ts ??? **)
| awEsRTCrfl: forall ts, awndEvalsRTC ts ts
| awEsRTCstep: forall ts ss, awndEvals ts ss -> awndEvalsRTC ts ss
| awEsRTCtrn: forall ts ss us,
       awndEvalsRTC ts ss -> awndEvalsRTC ss us -> awndEvalsRTC ts us.
Hint Constructors awndEvalRTC awndEvalsRTC.


Lemma awndEvalRTC_pres_WFapp:
  WFaEnv p ->
  forall t s, awndEvalRTC t s -> WFapp t -> WFapp s.
Proof.
  intros hp.
  induction 1; intros; try assumption.
  - eapply (proj1 (awndEval_pres_WFapp hp)); eassumption.
  - apply IHawndEvalRTC2; try assumption.
    + apply IHawndEvalRTC1; assumption.
Qed.

Lemma awndEvalRTC_App_fn:
  forall fn fn',
    awndEvalRTC fn fn' -> 
    forall a1 args,
      awndEvalRTC (mkApp fn (tcons a1 args)) (mkApp fn' (tcons a1 args)).
induction 1; intros.
- apply awERTCrfl.
- constructor. apply aAppFn. assumption.
- eapply awERTCtrn. 
  + apply IHawndEvalRTC1.
  + apply IHawndEvalRTC2.
Qed.

End Env.
Hint Constructors awndEval awndEvals.
Hint Constructors awndEvalRTC awndEvalsRTC.


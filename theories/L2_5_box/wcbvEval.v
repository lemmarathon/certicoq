Require Import FunInd.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.Program.Basics.
Require Import Coq.omega.Omega.
Require Import Coq.Logic.JMeq.
Require Import Common.Common.
Require Import L2_5.term.
Require Import L2_5.program.

Delimit Scope string_scope with string.
Open Scope string_scope.
Open Scope string_scope.
Open Scope bool.
Open Scope list.
Set Implicit Arguments.


(** Big step relation of weak cbv evaluation  **)
(** every field must evaluate **)
Inductive WcbvEval (p:environ Term) : Term -> Term -> Prop :=
| wLam: forall nm bod, WcbvEval p (TLambda nm bod) (TLambda nm bod)
| wProof: WcbvEval p TProof TProof
| waPrf: forall fn arg,
    WcbvEval p fn TProof -> WcbvEval p (TApp fn arg) TProof
| wConstruct: forall i r args args',
    WcbvEvals p args args' ->
    WcbvEval p (TConstruct i r args) (TConstruct i r args')
| wFix: forall dts m, WcbvEval p (TFix dts m) (TFix dts m)
| wDummy: forall str, WcbvEval p (TDummy str) (TDummy str)
| wConst: forall nm (t s:Term),
    lookupDfn nm p = Ret t -> WcbvEval p t s -> WcbvEval p (TConst nm) s
| wAppLam: forall (fn bod a1 a1' s:Term) (nm:name),
    WcbvEval p fn (TLambda nm bod) ->
    WcbvEval p a1 a1' ->
    WcbvEval p (whBetaStep bod a1') s ->
    WcbvEval p (TApp fn a1) s
| wLetIn: forall (nm:name) (dfn bod dfn' s:Term),
    WcbvEval p dfn dfn' ->
    WcbvEval p (instantiate dfn' 0 bod) s ->
    WcbvEval p (TLetIn nm dfn bod) s
| wAppFix: forall dts m (fn arg s x:Term),
    WcbvEval p fn (TFix dts m) ->
    dnthBody m dts = Some x ->
    WcbvEval p (pre_whFixStep x dts arg) s ->
    WcbvEval p (TApp fn arg) s 
| wAppCong: forall fn fn' arg arg', 
    WcbvEval p fn fn' -> (isApp fn' \/ isDummy fn') ->
    WcbvEval p arg arg' ->
    WcbvEval p (TApp fn arg) (TApp fn' arg') 
| wCase: forall mch i n args brs cs s,
    WcbvEval p mch (TConstruct i n args) ->
    whCaseStep n args brs = Some cs ->
    WcbvEval p cs s ->
    WcbvEval p (TCase i mch brs) s
with WcbvEvals (p:environ Term) : Terms -> Terms -> Prop :=
     | wNil: WcbvEvals p tnil tnil
     | wCons: forall t t' ts ts',
         WcbvEval p t t' -> WcbvEvals p ts ts' -> 
         WcbvEvals p (tcons t ts) (tcons t' ts').
Hint Constructors WcbvEval WcbvEvals.
Scheme WcbvEval1_ind := Induction for WcbvEval Sort Prop
     with WcbvEvals1_ind := Induction for WcbvEvals Sort Prop.
Combined Scheme WcbvEvalEvals_ind from WcbvEval1_ind, WcbvEvals1_ind.

(** evaluate omega = (\x.xx)(\x.xx): nontermination **)
Definition xx := (TLambda nAnon (TApp (TRel 0) (TRel 0))).
Definition xxxx := (TApp xx xx).
Goal WcbvEval nil xxxx xxxx.
unfold xxxx, xx.
eapply wAppLam. eapply wLam. 
eapply wLam. 
change (WcbvEval nil xxxx xxxx).
Abort.


Lemma WcbvEval_mkApp_nil:
  forall t, WFapp t -> forall p s, WcbvEval p t s ->
                 WcbvEval p (mkApp t tnil) s.
Proof.
  intros p. induction 1; simpl; intros; try assumption.
Qed.

Lemma WcbvEvals_tcons_tcons:
  forall p arg args brgs, WcbvEvals p (tcons arg args) brgs ->
                          exists crg crgs, brgs = (tcons crg crgs).
Proof.
  inversion 1. exists t', ts'. reflexivity.
Qed.

Lemma WcbvEvals_tcons_tcons':
  forall p arg brg args brgs,
    WcbvEvals p (tcons arg args) (tcons brg brgs) ->
    WcbvEval p arg brg /\ WcbvEvals p args brgs.
Proof.
  inversion 1. intuition.
Qed.

Lemma WcbvEvals_pres_tlength:
  forall p args brgs, WcbvEvals p args brgs -> tlength args = tlength brgs.
Proof.
  induction 1. reflexivity. cbn. rewrite IHWcbvEvals. reflexivity.
Qed.

(** wcbvEval preserves WFapp **)
Lemma wcbvEval_pres_WFapp:
  forall p, WFaEnv p -> 
   (forall t s, WcbvEval p t s -> WFapp t -> WFapp s) /\
   (forall ts ss, WcbvEvals p ts ss -> WFapps ts -> WFapps ss).
Proof.
  intros p hp.
  apply WcbvEvalEvals_ind; intros; try assumption;
  try (solve[inversion_Clear H0; intuition]);
  try (solve[inversion_Clear H1; intuition]).
  - apply H. unfold lookupDfn in e. case_eq (lookup nm p); intros xc.
    + intros k. assert (j:= lookup_pres_WFapp hp _ k).
      rewrite k in e. destruct xc. 
      * myInjection e. inversion j. assumption.
      * discriminate.
    + rewrite xc in e. discriminate.
  - inversion_clear H2. apply H1.
    specialize (H H3). inversion_Clear H.
    apply (whBetaStep_pres_WFapp); intuition. 
  - inversion_Clear H1. apply H0. apply instantiate_pres_WFapp; intuition.
  - inversion_clear H1. specialize (H H2). inversion_Clear H.
    apply H0. apply pre_whFixStep_pres_WFapp; try eassumption; intuition.
    eapply dnthBody_pres_WFapp; eassumption.
  - apply H0. inversion_Clear H1.
    eapply whCaseStep_pres_WFapp; try eassumption.
    specialize (H H4). inversion_Clear H. assumption.
Qed.

Lemma WcbvEval_weaken:
  forall p,
  (forall t s, WcbvEval p t s -> forall nm ec, fresh nm p ->
                   WcbvEval ((nm,ec)::p) t s) /\
  (forall ts ss, WcbvEvals p ts ss -> forall nm ec, fresh nm p ->
                   WcbvEvals ((nm,ec)::p) ts ss).
Proof.
  intros p. apply WcbvEvalEvals_ind; intros; auto.
  - destruct (string_dec nm nm0).
    + subst. 
      * unfold lookupDfn in e.
        rewrite (proj1 (fresh_lookup_None (trm:=Term) _ _) H0) in e.
        discriminate.
    + eapply wConst.
      * rewrite <- (lookupDfn_weaken' n). eassumption. 
      * apply H. assumption. 
  - eapply wAppLam.
    + apply H. assumption.
    + apply H0. assumption.
    + apply H1. assumption.
  - eapply wLetIn; intuition.
  - eapply wAppFix; try eassumption; intuition.
  - eapply wCase; intuition; eassumption.
Qed.

Lemma pre_WcbvEval_single_valued:
  forall p,
  (forall t s, WcbvEval p t s -> forall u, WcbvEval p t u -> s = u) /\
  (forall t s, WcbvEvals p t s -> forall u, WcbvEvals p t u -> s = u).
Proof.
  intros p.
  apply WcbvEvalEvals_ind; intros; try (inversion_Clear H; reflexivity).
  - inversion_Clear H0.
    + reflexivity.
    + specialize (H _ H3). discriminate.
    + specialize (H _ H3). discriminate.
    + destruct H4.
      * destruct H0 as [x0 [x1 jx]]. subst. specialize (H _ H3).
        discriminate.
      * destruct H0 as [x0 jx]. subst. specialize (H _ H3).
        discriminate.
  - inversion_Clear H0. apply f_equal3; try reflexivity.
    eapply H. assumption.
  - inversion_Clear H0. rewrite H2 in e. myInjection e.
    eapply H. assumption.
  - inversion_Clear H2.
    + specialize (H _ H6). discriminate.
    + specialize (H _ H5). myInjection H.
      specialize (H0 _ H6). subst.
      eapply H1. assumption.
    + specialize (H _ H5). discriminate.
    + specialize (H _ H5). specialize (H0 _ H8). subst. destruct H6.
      * destruct H as [x0 [x1 jx]]. discriminate.
      * destruct H as [x0 jx]. discriminate.
  - inversion_Clear H1. specialize (H _ H6). subst.
    eapply H0. assumption.
  - inversion_Clear H1.
    + specialize (H _ H5). discriminate.
    + specialize (H _ H4). discriminate. 
    + specialize (H _ H4). myInjection H. rewrite H5 in e. myInjection e.
      intuition.
    + specialize (H _ H4). subst. destruct H5.
      * destruct H as [x0 [x1 jx]]. discriminate.
      * destruct H as [x0 jx]. discriminate.
  - inversion_Clear H1.
    + specialize (H _ H5). subst. destruct o.
      * destruct H as [x0 [x1 jx]]. discriminate.
      * destruct H as [x0 jx]. discriminate.
    + specialize (H _ H4). subst. destruct o.
      * destruct H as [x0 [x1 jx]]. discriminate.
      * destruct H as [x0 jx]. discriminate.
    + specialize (H _ H4). subst. destruct o.
      * destruct H as [x0 [x1 jx]]. discriminate.
      * destruct H as [x0 jx]. discriminate.
    + specialize (H _ H4). specialize (H0 _ H7). subst. reflexivity.
  - inversion_Clear H1.
    + specialize (H _ H5). myInjection H. rewrite H7 in e.
      myInjection e. intuition. 
  - inversion_Clear H1. specialize (H _ H4). specialize (H0 _ H6). subst.
    reflexivity.
Qed.

Lemma WcbvEval_single_valued:
  forall p t s, WcbvEval p t s -> forall u, WcbvEval p t u -> s = u.
Proof.
  intros. eapply (proj1 (pre_WcbvEval_single_valued p)); eassumption.
Qed.

Lemma sv_cor:
  forall p fn fn' t s,
    WcbvEval p fn t -> WcbvEval p fn' t -> WcbvEval p fn s -> WcbvEval p fn' s.
Proof.
  intros. rewrite <- (WcbvEval_single_valued H H1). assumption.
Qed.
  
Lemma WcbvEval_no_further:
  forall p,
    (forall t s, WcbvEval p t s -> WcbvEval p s s) /\
    (forall t s, WcbvEvals p t s -> WcbvEvals p s s).
Proof.
  intros p; apply WcbvEvalEvals_ind; intros; auto.
Qed.

Lemma WcbvEval_trn:
  forall p s t,
    WcbvEval p s t ->
    forall u,
      WcbvEval p t u -> WcbvEval p s u.
Proof.
  intros.
  pose proof (proj1 (WcbvEval_no_further p) _ _ H) as j0.
  rewrite (WcbvEval_single_valued H0 j0).
  assumption.
Qed.


Section wcbvEval_sec.
Variable p:environ Term.

Function wcbvEval
         (tmr:nat) (t:Term) {struct tmr}: exception Term :=
  match tmr with 
  | 0 => raise ("out of time: " ++ print_term t)
  | S n =>
    match t with      (** look for a redex **)
    | TConst nm =>
      match (lookup nm p) with
      | Some (AstCommon.ecTrm t) => wcbvEval n t
      (** note hack coding of axioms in environment **)
      | Some (AstCommon.ecTyp _ _ _) =>
        raise ("wcbvEval, TConst ecTyp " ++ nm)
      | _ => raise "wcbvEval: TConst environment miss"
      end
    | TApp fn a1 =>
      match wcbvEval n fn with
      | Ret (TLambda _ bod) =>
        match wcbvEval n a1 with
        | Exc s =>  raise ("wcbvEval, TAppLam, arg: " ++ s)
        | Ret b1 => wcbvEval n (whBetaStep bod b1)
        end
      | Ret (TFix dts m) =>           (* Fix redex *)
        match dnthBody m dts with
        | None => raise ("wcbvEval TApp: dnthBody doesn't eval: ")
        | Some x => wcbvEval n (pre_whFixStep x dts a1)
        end
      | Ret ((TApp _ _) as u)
      | Ret ((TDummy _) as u) =>
        match wcbvEval n a1 with
            | Ret ea1 => ret (TApp u ea1)
            | Exc s => raise ("(wcbvEval;TAppCong: " ++ s ++ ")")
        end
      | Ret TProof => Ret TProof  (* proof redex *)
      | _ => raise "wcbvEval, TApp: fn"
      end
   | TCase ml mch brs =>
      match wcbvEval n mch with
      | Ret (TConstruct i ix args) =>
        match inductive_dec i ml with
        | left _ =>
          match whCaseStep ix args brs with
          | None => raise "wcbvEval: Case, whCaseStep"
          | Some cs => wcbvEval n cs
          end
        | right _ => raise "wcbvEval: Case, constructor of wrong type"
        end
      | _ => raise "wcbvEval: Case, discriminee not canonical"
      end
    | TLetIn nm df bod =>
      match wcbvEval n df with
      | Ret df' => wcbvEval n (instantiate df' 0 bod)
      | Exc s => raise ("wcbvEval, TLetIn, def: " ++ s)
      end
    | TConstruct i cn args =>
      match wcbvEvals n args with
      | Ret args' => ret (TConstruct i cn args')
      | Exc s => raise ("wcbvEval: TConstruct, args: " ++ s)
      end
    (** already in whnf ***)
    | TDummy str => ret (TDummy str)
    | TLambda nn t => ret (TLambda nn t)
    | TFix mfp br => ret (TFix mfp br)
    | TProof => ret TProof
    (** should never appear **)
    | TRel _ => raise "wcbvEval:unbound Rel"
    | (TWrong s) as u => raise (print_term u)
    end
  end
with wcbvEvals (tmr:nat) (ts:Terms) {struct tmr}
     : exception Terms :=
       (match tmr with 
        | 0 => raise "out of time"
        | S n => match ts with             (** look for a redex **)
                 | tnil => ret tnil
                 | tcons s ss =>
                   match wcbvEval n s, wcbvEvals n ss with
                   | Ret es, Ret ess => ret (tcons es ess)
                   | Exc s, _ => raise ("wcbvEvals, hd: " ++ s)
                   | Ret _, Exc s => raise ("wcbvEvals, tl: " ++ s)
                   end
                 end
        end).
Functional Scheme wcbvEval_ind' := Induction for wcbvEval Sort Prop
with wcbvEvals_ind' := Induction for wcbvEvals Sort Prop.
Combined Scheme wcbvEvalEvals_ind from wcbvEval_ind', wcbvEvals_ind'.


(** wcbvEval and WcbvEval are the same relation **)
Lemma wcbvEval_WcbvEval:
  forall tmr,
  (forall t s, wcbvEval tmr t = Ret s -> WcbvEval p t s) /\
  (forall ts ss, wcbvEvals tmr ts = Ret ss -> WcbvEvals p ts ss).
Proof.
  intros tmr.
  apply (wcbvEvalEvals_ind
           (fun tmr t su => forall u (p1:su = Ret u), WcbvEval p t u)
           (fun tmr t su => forall u (p1:su = Ret u), WcbvEvals p t u));
    intros; try discriminate; try (myInjection p1);
    try(solve[constructor]); intuition.
  - eapply wConst; intuition.
    + unfold lookupDfn. rewrite e1. reflexivity.
  - specialize (H1 _ p1). specialize (H _ e1). specialize (H0 _ e2).
    eapply wAppLam; eassumption.
  - specialize (H0 _ p1). specialize (H _ e1).
    eapply wAppFix; try eassumption.
  - eapply wCase; try eassumption.
    + apply H. rewrite <- _x. apply e1. 
    + apply H0; eassumption. 
  - eapply wLetIn; intuition.
    + apply H. assumption.
Qed.

Lemma wcbvEvals_tcons_tcons:
  forall m args brg brgs,
    wcbvEvals m args = Ret (tcons brg brgs) ->
    forall crg crgs, args = (tcons crg crgs) ->
                     wcbvEval (pred m) crg = Ret brg.
Proof.
  intros m args.
  functional induction (wcbvEvals m args); intros; try discriminate.
  myInjection H0. myInjection H. assumption.
Qed.

(** need strengthening to large-enough fuel to make the induction
 *** go through **)
Lemma pre_WcbvEval_wcbvEval:
    (forall t s, WcbvEval p t s ->
          exists n, forall m, m >= n -> wcbvEval (S m) t = Ret s) /\
    (forall ts ss, WcbvEvals p ts ss ->
                   exists n, forall m, m >= n -> wcbvEvals (S m) ts = Ret ss).
Proof.
  assert (j:forall m, m > 0 -> m = S (m - 1)).
  { induction m; intuition. }
  apply WcbvEvalEvals_ind; intros; try (exists 0; intros mx h; reflexivity).
  - destruct H. exists (S x). intros m hm. simpl. rewrite (j m); try omega.
    + rewrite (H (m - 1)); try omega. reflexivity.
  - destruct H. exists (S x). intros m h. simpl.
    rewrite (j m); try omega. rewrite H; try omega. reflexivity.
  - destruct H. exists (S x). intros mm h. simpl.
    rewrite (j mm); try omega.
    unfold lookupDfn in e. destruct (lookup nm p). destruct e0. myInjection e.
    + rewrite H. reflexivity. omega.
    + discriminate.
    + discriminate.
  - destruct H, H0, H1. exists (S (max x (max x0 x1))). intros m h.
    assert (j1:= max_fst x (max x0 x1)). 
    assert (lx: m > x). omega.
    assert (j2:= max_snd x (max x0 x1)).
    assert (j3:= max_fst x0 x1).
    assert (lx0: m > x0). omega.
    assert (j4:= max_snd x0 x1).
    assert (j5:= max_fst x0 x1).
    assert (lx1: m > x1). omega.
    assert (k:wcbvEval m fn = Ret (TLambda nm bod)).
    + rewrite (j m). apply H.
      assert (l:= max_fst x (max x0 x1)); omega. omega.
    + assert (k0:wcbvEval m a1 = Ret a1').
      * rewrite (j m). apply H0. 
        assert (l:= max_snd x (max x0 x1)). assert (l':= max_fst x0 x1).
        omega. omega.
      * simpl. rewrite (j m); try omega.
        rewrite H; try omega. rewrite H0; try omega. rewrite H1; try omega.
        reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite (H (mx - 1)); try omega.
    rewrite H0; try omega. reflexivity.
  - destruct H, H0. exists (S (max x0 x1)). intros mx h.
    assert (l1:= max_fst x0 x1). assert (l2:= max_snd x0 x1).
    simpl. rewrite (j mx); try omega. rewrite H; try omega.
    rewrite e. rewrite H0; try omega. reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    cbn. rewrite (j mx); try omega. rewrite H; try omega.
    destruct o.
    + destruct H1 as [y0 [y1 jy]]. subst.
      rewrite H0. reflexivity. omega.
    + destruct H1 as [y0 jy]. subst.
      rewrite H0. reflexivity. omega.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite (H (mx - 1)); try omega.
    destruct (inductive_dec i i).
    + rewrite e. rewrite H0. reflexivity. omega.
    + elim n0. reflexivity.
  - destruct H, H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx); try omega. rewrite (H (mx - 1)); try omega.
    rewrite H0; try omega. reflexivity.
Qed.

Lemma WcbvEval_wcbvEval:
  forall t s, WcbvEval p t s ->
             exists n, forall m, m >= n -> wcbvEval m t = Ret s.
Proof.
  intros t s h.
  destruct (proj1 pre_WcbvEval_wcbvEval _ _ h).
  exists (S x). intros m hm. specialize (H (m - 1)).
  assert (k: m = S (m - 1)). { omega. }
  rewrite k. apply H. omega.
Qed.

End wcbvEval_sec.

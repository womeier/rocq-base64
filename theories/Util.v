(** * Small list utilities

    Helpers the base64 development needs that the standard library does not
    provide: [index_of], a partial inverse to [nth], and induction principles
    that step through a list three or four elements at a time -- the shapes
    base64 encoding and decoding respectively recurse on. *)

From Stdlib Require Import Lists.List.
From Stdlib Require Import Arith.PeanoNat.
From Stdlib Require Import Lia.
Import ListNotations.

(** ** Finding the position of an element *)

Section IndexOf.

  Context {A : Type} (eqb : A -> A -> bool).
  Context (eqb_true : forall x y, eqb x y = true -> x = y).
  Context (eqb_refl : forall x, eqb x x = true).

  (** [index_of x l] is the position of the first occurrence of [x] in [l]. *)
  Fixpoint index_of (x : A) (l : list A) : option nat :=
    match l with
    | [] => None
    | y :: l => if eqb x y then Some 0 else option_map S (index_of x l)
    end.

  (** An element that does not occur has no position. *)
  Lemma index_of_not_In x l : ~ In x l -> index_of x l = None.
  Proof.
    induction l as [|y l IH]; intros Hnin; [reflexivity|]. simpl.
    destruct (eqb x y) eqn:Heq.
    - apply eqb_true in Heq. subst. exfalso. apply Hnin. now left.
    - rewrite IH; [reflexivity|]. intros Hin. apply Hnin. now right.
  Qed.

  (** A reported position is in bounds and really holds the element. *)
  Lemma index_of_Some x l n d :
    index_of x l = Some n -> n < length l /\ nth n l d = x.
  Proof.
    revert n. induction l as [|y l IH]; intros n H; [discriminate|].
    simpl in H. destruct (eqb x y) eqn:Heq.
    - apply eqb_true in Heq. injection H as <-. subst. simpl. split; [lia|reflexivity].
    - destruct n as [|m].
      + destruct (index_of x l); simpl in H; discriminate.
      + assert (index_of x l = Some m) as Hi.
        { destruct (index_of x l) as [k|]; simpl in H; [|discriminate].
          injection H as H. now rewrite H. }
        destruct (IH m Hi) as [Hlt Hnth]. simpl. split; [lia|assumption].
  Qed.

  (** On a duplicate-free list, [index_of] inverts [nth]. *)
  Lemma index_of_nth l n d :
    NoDup l -> n < length l -> index_of (nth n l d) l = Some n.
  Proof.
    revert n. induction l as [|y l IH]; intros n Hnd Hlt; simpl in Hlt; [lia|].
    apply NoDup_cons_iff in Hnd as [Hnin Hnd].
    destruct n as [|n]; simpl.
    - now rewrite eqb_refl.
    - destruct (eqb (nth n l d) y) eqn:Heq.
      + apply eqb_true in Heq. exfalso. apply Hnin. rewrite <- Heq.
        apply nth_In. lia.
      + rewrite (IH n Hnd) by lia. reflexivity.
  Qed.

End IndexOf.

(** ** Induction in steps of three and four

    [encode] consumes its input three bytes at a time and [decode] consumes
    four characters at a time, so neither is structurally recursive in a way
    plain [list_ind] can follow. These principles mirror their match shapes. *)

Lemma list_ind3 {A : Type} (P : list A -> Prop) :
  P [] ->
  (forall a, P [a]) ->
  (forall a b, P [a; b]) ->
  (forall a b c l, P l -> P (a :: b :: c :: l)) ->
  forall l, P l.
Proof.
  intros H0 H1 H2 H3.
  assert (forall n l, length l <= n -> P l) as Haux.
  { induction n as [|n IH]; intros [|a [|b [|c l]]] Hlen; simpl in Hlen;
      try lia; try apply H0; try apply H1; try apply H2.
    apply H3. apply IH. lia. }
  intros l. now apply (Haux (length l)).
Qed.

Lemma list_ind4 {A : Type} (P : list A -> Prop) :
  P [] ->
  (forall a, P [a]) ->
  (forall a b, P [a; b]) ->
  (forall a b c, P [a; b; c]) ->
  (forall a b c d l, P l -> P (a :: b :: c :: d :: l)) ->
  forall l, P l.
Proof.
  intros H0 H1 H2 H3 H4.
  assert (forall n l, length l <= n -> P l) as Haux.
  { induction n as [|n IH]; intros [|a [|b [|c [|d l]]]] Hlen; simpl in Hlen;
      try lia; try apply H0; try apply H1; try apply H2; try apply H3.
    apply H4. apply IH. lia. }
  intros l. now apply (Haux (length l)).
Qed.

(** * Sextets: the six-bit groups base64 is built from

    Base64 reinterprets a stream of 8-bit bytes as a stream of 6-bit groups.
    This file defines those groups and the bit-level repacking between them,
    which is where all of base64's real content lives.

    Everything here is phrased with [Byte.to_bits] / [Byte.of_bits], so no
    arithmetic is ever needed: each repacking lemma is a finite check that the
    bits come back in the order they went in. Note that [Byte.to_bits] is
    *least* significant bit first, whereas base64 reads the stream most
    significant bit first, so the two orders are reversed with respect to each
    other throughout. *)

From Stdlib Require Import Strings.Byte.
From Stdlib Require Import Arith.PeanoNat.
From Stdlib Require Import Lia.

(** ** The type of sextets *)

(** Fields are named after the power of two they carry, so [bit5] is the most
    significant bit. *)
Record sextet := Sextet {
  bit5 : bool; bit4 : bool; bit3 : bool; bit2 : bool; bit1 : bool; bit0 : bool
}.

Definition sextet_to_nat (s : sextet) : nat :=
  32 * Nat.b2n (bit5 s) + 16 * Nat.b2n (bit4 s) + 8 * Nat.b2n (bit3 s)
   + 4 * Nat.b2n (bit2 s) + 2 * Nat.b2n (bit1 s) + Nat.b2n (bit0 s).

Definition nat_to_sextet (n : nat) : sextet :=
  Sextet (Nat.testbit n 5) (Nat.testbit n 4) (Nat.testbit n 3)
         (Nat.testbit n 2) (Nat.testbit n 1) (Nat.testbit n 0).

Lemma nat_to_sextet_to_nat s : nat_to_sextet (sextet_to_nat s) = s.
Proof. destruct s as [[][][][][][]]; reflexivity. Qed.

Lemma sextet_to_nat_lt s : sextet_to_nat s < 64.
Proof. destruct s as [[][][][][][]]; cbn; lia. Qed.

(** ** Repacking 3 bytes into 4 sextets (and back)

    The 24 bits of three bytes, read most significant first, split evenly into
    four sextets. Bit [i] of a byte is written [_i] below, so [x7] is the most
    significant bit of [x]. *)

Definition sextets_of_3 (x y z : byte) : sextet * sextet * sextet * sextet :=
  let '(x0,(x1,(x2,(x3,(x4,(x5,(x6,x7))))))) := Byte.to_bits x in
  let '(y0,(y1,(y2,(y3,(y4,(y5,(y6,y7))))))) := Byte.to_bits y in
  let '(z0,(z1,(z2,(z3,(z4,(z5,(z6,z7))))))) := Byte.to_bits z in
  (Sextet x7 x6 x5 x4 x3 x2,
   Sextet x1 x0 y7 y6 y5 y4,
   Sextet y3 y2 y1 y0 z7 z6,
   Sextet z5 z4 z3 z2 z1 z0).

Definition bytes_of_4 (s t u v : sextet) : byte * byte * byte :=
  (Byte.of_bits (bit4 t,(bit5 t,(bit0 s,(bit1 s,(bit2 s,(bit3 s,(bit4 s,(bit5 s)))))))),
   Byte.of_bits (bit2 u,(bit3 u,(bit4 u,(bit5 u,(bit0 t,(bit1 t,(bit2 t,(bit3 t)))))))),
   Byte.of_bits (bit0 v,(bit1 v,(bit2 v,(bit3 v,(bit4 v,(bit5 v,(bit0 u,(bit1 u))))))))).

(** ** Repacking 2 bytes into 3 sextets, and 1 byte into 2 sextets

    A short final group leaves spare low bits in the last sextet. Encoding sets
    them to zero; decoding *insists* they are zero, which is what makes the
    decoder reject non-canonical input. That check is the [option] below. *)

Definition sextets_of_2 (x y : byte) : sextet * sextet * sextet :=
  let '(x0,(x1,(x2,(x3,(x4,(x5,(x6,x7))))))) := Byte.to_bits x in
  let '(y0,(y1,(y2,(y3,(y4,(y5,(y6,y7))))))) := Byte.to_bits y in
  (Sextet x7 x6 x5 x4 x3 x2,
   Sextet x1 x0 y7 y6 y5 y4,
   Sextet y3 y2 y1 y0 false false).

Definition bytes_of_3 (s t u : sextet) : option (byte * byte) :=
  if orb (bit1 u) (bit0 u) then None else
  Some (Byte.of_bits (bit4 t,(bit5 t,(bit0 s,(bit1 s,(bit2 s,(bit3 s,(bit4 s,(bit5 s)))))))),
        Byte.of_bits (bit2 u,(bit3 u,(bit4 u,(bit5 u,(bit0 t,(bit1 t,(bit2 t,(bit3 t))))))))).

Definition sextets_of_1 (x : byte) : sextet * sextet :=
  let '(x0,(x1,(x2,(x3,(x4,(x5,(x6,x7))))))) := Byte.to_bits x in
  (Sextet x7 x6 x5 x4 x3 x2,
   Sextet x1 x0 false false false false).

Definition bytes_of_2 (s t : sextet) : option byte :=
  if orb (bit3 t) (orb (bit2 t) (orb (bit1 t) (bit0 t))) then None else
  Some (Byte.of_bits (bit4 t,(bit5 t,(bit0 s,(bit1 s,(bit2 s,(bit3 s,(bit4 s,(bit5 s))))))))).

(** ** The repackings are mutually inverse

    Each pair of lemmas below is checked by computation, so they only go
    through if the bit layouts above really do match up. *)

Lemma bytes_of_4_sextets_of_3 x y z s t u v :
  sextets_of_3 x y z = (s, t, u, v) -> bytes_of_4 s t u v = (x, y, z).
Proof.
  unfold sextets_of_3, bytes_of_4.
  destruct (Byte.to_bits x) as (x0&x1&x2&x3&x4&x5&x6&x7) eqn:Hx.
  destruct (Byte.to_bits y) as (y0&y1&y2&y3&y4&y5&y6&y7) eqn:Hy.
  destruct (Byte.to_bits z) as (z0&z1&z2&z3&z4&z5&z6&z7) eqn:Hz.
  intros H. injection H as <- <- <- <-.
  cbn [bit0 bit1 bit2 bit3 bit4 bit5].
  rewrite <- Hx, <- Hy, <- Hz, !Byte.of_bits_to_bits. reflexivity.
Qed.

Lemma bytes_of_3_sextets_of_2 x y s t u :
  sextets_of_2 x y = (s, t, u) -> bytes_of_3 s t u = Some (x, y).
Proof.
  unfold sextets_of_2, bytes_of_3.
  destruct (Byte.to_bits x) as (x0&x1&x2&x3&x4&x5&x6&x7) eqn:Hx.
  destruct (Byte.to_bits y) as (y0&y1&y2&y3&y4&y5&y6&y7) eqn:Hy.
  intros H. injection H as <- <- <-.
  cbn [bit0 bit1 bit2 bit3 bit4 bit5 orb].
  rewrite <- Hx, <- Hy, !Byte.of_bits_to_bits. reflexivity.
Qed.

Lemma bytes_of_2_sextets_of_1 x s t :
  sextets_of_1 x = (s, t) -> bytes_of_2 s t = Some x.
Proof.
  unfold sextets_of_1, bytes_of_2.
  destruct (Byte.to_bits x) as (x0&x1&x2&x3&x4&x5&x6&x7) eqn:Hx.
  intros H. injection H as <- <-.
  cbn [bit0 bit1 bit2 bit3 bit4 bit5 orb].
  rewrite <- Hx, Byte.of_bits_to_bits. reflexivity.
Qed.

(** The backward direction needs a little care. [injection] normalises its
    hypothesis far enough to expose constructors, which in particular unfolds
    [Byte.of_bits] into its 256-way decision tree and destroys the bit pattern
    we want to reason about. So each backward lemma is proved first in a form
    that binds the result of the repacking with a [match], where no inversion
    is needed, and the usable implication is derived from it by inverting an
    equation between plain variables. *)

Lemma sextets_of_3_bytes_of_4_match s t u v :
  let '(x, y, z) := bytes_of_4 s t u v in sextets_of_3 x y z = (s, t, u, v).
Proof.
  unfold bytes_of_4, sextets_of_3.
  cbn [bit0 bit1 bit2 bit3 bit4 bit5].
  rewrite !Byte.to_bits_of_bits.
  destruct s, t, u, v. reflexivity.
Qed.

Lemma sextets_of_3_bytes_of_4 x y z s t u v :
  bytes_of_4 s t u v = (x, y, z) -> sextets_of_3 x y z = (s, t, u, v).
Proof.
  pose proof (sextets_of_3_bytes_of_4_match s t u v) as HH.
  destruct (bytes_of_4 s t u v) as [[a b] c].
  intros H. injection H as <- <- <-. exact HH.
Qed.

Lemma sextets_of_2_bytes_of_3_match s t u :
  match bytes_of_3 s t u with
  | Some (x, y) => sextets_of_2 x y = (s, t, u)
  | None => True
  end.
Proof.
  unfold bytes_of_3, sextets_of_2. destruct u as [u5 u4 u3 u2 u1 u0].
  destruct u1, u0; cbn [bit0 bit1 bit2 bit3 bit4 bit5 orb]; try exact I.
  rewrite !Byte.to_bits_of_bits. destruct s, t. reflexivity.
Qed.

Lemma sextets_of_2_bytes_of_3 x y s t u :
  bytes_of_3 s t u = Some (x, y) -> sextets_of_2 x y = (s, t, u).
Proof.
  pose proof (sextets_of_2_bytes_of_3_match s t u) as HH.
  destruct (bytes_of_3 s t u) as [[a b]|]; intros H; [|discriminate].
  injection H as <- <-. exact HH.
Qed.

Lemma sextets_of_1_bytes_of_2_match s t :
  match bytes_of_2 s t with
  | Some x => sextets_of_1 x = (s, t)
  | None => True
  end.
Proof.
  unfold bytes_of_2, sextets_of_1. destruct t as [t5 t4 t3 t2 t1 t0].
  destruct t3, t2, t1, t0; cbn [bit0 bit1 bit2 bit3 bit4 bit5 orb]; try exact I.
  rewrite Byte.to_bits_of_bits. destruct s. reflexivity.
Qed.

Lemma sextets_of_1_bytes_of_2 x s t :
  bytes_of_2 s t = Some x -> sextets_of_1 x = (s, t).
Proof.
  pose proof (sextets_of_1_bytes_of_2_match s t) as HH.
  destruct (bytes_of_2 s t) as [a|]; intros H; [|discriminate].
  injection H as <-. exact HH.
Qed.

(** A sanity check on the bit layout: "Man" is the textbook example, encoding
    to sextets 19, 22, 5, 46 (that is, "TWFu"). *)
Example sextets_of_3_Man :
  let '(s,t,u,v) := sextets_of_3 "M" "a" "n" in
  (sextet_to_nat s, sextet_to_nat t, sextet_to_nat u, sextet_to_nat v)
  = (19, 22, 5, 46).
Proof. reflexivity. Qed.

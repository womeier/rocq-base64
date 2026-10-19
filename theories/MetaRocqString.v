(** * Base64 on MetaRocq bytestrings

    MetaRocq represents strings as [MetaRocq.Utils.bytestring.String.t], an
    inductive list of bytes. It already comes with [print] and [parse] mapping
    to and from [list byte], so base64 on bytestrings is the core development
    transported along that pair.

    Every lemma below is oriented so that rewriting with it moves [print]
    inwards and leaves a goal about [list byte] -- see the [base64] rewrite
    database at the end of the file. *)

From Stdlib Require Import Strings.Byte Lists.List Arith.PeanoNat.
From MetaRocq.Utils Require bytestring.
From Base64 Require Import Sextet Alphabet Base64.
Import ListNotations.

(** Introduced under an abbreviation: MetaRocq's [String] module would
    otherwise shadow the standard library's. *)
Module BS := MetaRocq.Utils.bytestring.String.

(** ** [print] and [parse] are mutually inverse

    MetaRocq proves [parse (print s) = s]; the other direction is not in the
    library but is immediate. *)

Lemma print_parse (l : list byte) : BS.print (BS.parse l) = l.
Proof. induction l as [|b l IH]; cbn; congruence. Qed.

Lemma parse_print (s : BS.t) : BS.parse (BS.print s) = s.
Proof. apply BS.print_parse_inv. Qed.

Lemma print_append (s t : BS.t) :
  BS.print (BS.append s t) = BS.print s ++ BS.print t.
Proof. induction s as [|b s IH]; cbn; congruence. Qed.

Lemma print_length (s : BS.t) : length (BS.print s) = BS.length s.
Proof. induction s as [|b s IH]; cbn; congruence. Qed.

(** ** Encoding and decoding bytestrings *)

Definition encode_bs (c : config) (s : BS.t) : BS.t :=
  BS.parse (encode c (BS.print s)).

Definition decode_bs (c : config) (s : BS.t) : option BS.t :=
  option_map BS.parse (decode c (BS.print s)).

(** ** Pushing the conversions through

    These are the equations to rewrite with: each one replaces an operation on
    bytestrings by the corresponding operation on byte lists. *)

Lemma encode_bs_eq c s : encode_bs c s = BS.parse (encode c (BS.print s)).
Proof. reflexivity. Qed.

Lemma decode_bs_eq c s :
  decode_bs c s = option_map BS.parse (decode c (BS.print s)).
Proof. reflexivity. Qed.

Lemma print_encode_bs c s : BS.print (encode_bs c s) = encode c (BS.print s).
Proof. unfold encode_bs. apply print_parse. Qed.

Lemma print_decode_bs c s :
  option_map BS.print (decode_bs c s) = decode c (BS.print s).
Proof.
  unfold decode_bs. destruct (decode c (BS.print s)) as [bs|]; cbn; [|reflexivity].
  now rewrite print_parse.
Qed.

Lemma encode_bs_parse c l : encode_bs c (BS.parse l) = BS.parse (encode c l).
Proof. unfold encode_bs. now rewrite print_parse. Qed.

Lemma decode_bs_parse c l :
  decode_bs c (BS.parse l) = option_map BS.parse (decode c l).
Proof. unfold decode_bs. now rewrite print_parse. Qed.

(** ** The roundtrip theorems, transported *)

Theorem decode_bs_encode_bs c s : wf c -> decode_bs c (encode_bs c s) = Some s.
Proof.
  intros Hwf. unfold decode_bs, encode_bs.
  rewrite print_parse, (decode_encode c (BS.print s) Hwf). cbn.
  now rewrite parse_print.
Qed.

Theorem encode_bs_decode_bs c s t :
  wf c -> decode_bs c s = Some t -> encode_bs c t = s.
Proof.
  intros Hwf H. unfold decode_bs in H. unfold encode_bs.
  destruct (decode c (BS.print s)) as [bs|] eqn:Hd; cbn in H; [|discriminate].
  injection H as <-. rewrite print_parse.
  rewrite (encode_decode c (BS.print s) bs Hwf Hd). apply parse_print.
Qed.

Corollary decode_bs_encode_bs_iff c s t :
  wf c -> decode_bs c s = Some t <-> encode_bs c t = s.
Proof.
  intros Hwf. split; [now apply encode_bs_decode_bs|].
  intros <-. now apply decode_bs_encode_bs.
Qed.

Corollary encode_bs_inj c s t : wf c -> encode_bs c s = encode_bs c t -> s = t.
Proof.
  intros Hwf Heq.
  assert (Some s = Some t) as H by
    (rewrite <- (decode_bs_encode_bs c s Hwf), <- (decode_bs_encode_bs c t Hwf), Heq;
     reflexivity).
  now injection H as <-.
Qed.

(** ** Length and compositionality *)

Lemma length_encode_bs c s : BS.length (encode_bs c s) = length (encode c (BS.print s)).
Proof. unfold encode_bs. now rewrite <- print_length, print_parse. Qed.

Corollary length_encode_bs_spec c s :
  BS.length (encode_bs c s) =
  if pad c then 4 * ((BS.length s + 2) / 3)
  else 4 * (BS.length s / 3) + match BS.length s mod 3 with
                               | 0 => 0
                               | 1 => 2
                               | _ => 3
                               end.
Proof. rewrite length_encode_bs, encode_length, print_length. reflexivity. Qed.

Theorem encode_bs_append c s t :
  BS.length s mod 3 = 0 ->
  encode_bs c (BS.append s t) = BS.append (encode_bs c s) (encode_bs c t).
Proof.
  intros Hlen. unfold encode_bs. rewrite print_append, encode_app
    by (now rewrite print_length).
  generalize (encode c (BS.print s)) (encode c (BS.print t)). clear.
  intros l1 l2. induction l1 as [|b l1 IH]; cbn; congruence.
Qed.

(** ** Rewrite database

    [autorewrite with base64] turns a goal about bytestrings into a goal about
    byte lists, where the core theory applies. *)

(* [encode_bs_eq] and [decode_bs_eq] are what make the database normalizing
   rather than merely simplifying: without them an [encode_bs c s] on an opaque
   [s] has no rewrite to fire, and a goal like
   [decode_bs c (encode_bs c s) = Some s] is left untouched.  With them it
   unfolds to the core operations under [BS.print]/[BS.parse], which
   [print_parse] then collapses. *)
#[export] Hint Rewrite encode_bs_eq decode_bs_eq
  print_parse parse_print print_append print_length
  print_encode_bs print_decode_bs encode_bs_parse decode_bs_parse : base64.

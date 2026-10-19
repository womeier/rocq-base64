(** * Agreement between the three representations

    [Base64], [MetaRocqString] and [PrimStrings] each define an encoder and a
    decoder, on [list byte], on MetaRocq bytestrings and on primitive strings
    respectively. This file shows they are all the same function viewed through
    the conversions, so a result proved in one representation transfers to the
    others.

    It also collects the rewrite databases. [base64_simpl] normalises a goal
    about any of the three representations into a goal about byte lists. *)

From Stdlib Require Import Strings.Byte Lists.List.
From Stdlib Require Import ZArith Lia.
From Stdlib Require Import Numbers.Cyclic.Int63.Uint63.
From Stdlib Require Strings.PrimString Strings.PrimStringAxioms Strings.PString.
From base64 Require Import Util Sextet Alphabet Base64 MetaRocqString PrimStrings.
Import ListNotations.

(** ** Converting directly between bytestrings and primitive strings *)

Definition pstring_of_bs (s : BS.t) : pstring := pstring_of_bytes (BS.print s).
Definition bs_of_pstring (s : pstring) : BS.t := BS.parse (bytes_of_pstring s).

(** A primitive string always fits, so this direction is unconditional. *)
Lemma pstring_of_bs_of_pstring s : pstring_of_bs (bs_of_pstring s) = s.
Proof.
  unfold pstring_of_bs, bs_of_pstring. rewrite print_parse.
  apply pstring_of_bytes_of_pstring.
Qed.

(** The other direction needs the bytestring to fit in a primitive string. *)
Lemma bs_of_pstring_of_bs s :
  (Z.of_nat (BS.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  bs_of_pstring (pstring_of_bs s) = s.
Proof.
  intros Hlen. unfold pstring_of_bs, bs_of_pstring.
  rewrite bytes_of_pstring_of_bytes by (now rewrite print_length).
  apply parse_print.
Qed.

(** The byte list underlying a converted bytestring is just its [print]. *)
Lemma bytes_of_pstring_of_bs s :
  (Z.of_nat (BS.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  bytes_of_pstring (pstring_of_bs s) = BS.print s.
Proof.
  intros Hlen. unfold pstring_of_bs.
  now rewrite bytes_of_pstring_of_bytes by (now rewrite print_length).
Qed.

Lemma length_pstring_of_bs s :
  (Z.of_nat (BS.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  Uint63.to_Z (PrimString.length (pstring_of_bs s)) = Z.of_nat (BS.length s).
Proof.
  intros Hlen. rewrite <- (length_bytes_of_pstring (pstring_of_bs s)).
  rewrite bytes_of_pstring_of_bs by exact Hlen. now rewrite print_length.
Qed.

(** ** The encoders agree

    All three encoders are the core [encode] conjugated by the relevant
    conversion, so each pair commutes. *)

Theorem encode_ps_of_bs c s :
  (Z.of_nat (BS.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_ps c (pstring_of_bs s) = pstring_of_bs (encode_bs c s).
Proof.
  intros Hs. unfold encode_ps, pstring_of_bs.
  rewrite bytes_of_pstring_of_bytes by (now rewrite print_length).
  now rewrite print_encode_bs.
Qed.

Theorem encode_bs_of_pstring c s :
  (Z.of_nat (length (encode c (bytes_of_pstring s)))
     <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_bs c (bs_of_pstring s) = bs_of_pstring (encode_ps c s).
Proof.
  intros Hlen. unfold bs_of_pstring, encode_bs, encode_ps.
  rewrite print_parse. f_equal. symmetry.
  now apply bytes_of_pstring_of_bytes.
Qed.

(** ** The decoders agree *)

Theorem decode_ps_of_bs c s :
  (Z.of_nat (BS.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (pstring_of_bs s) = option_map pstring_of_bytes (decode c (BS.print s)).
Proof.
  intros Hs. unfold decode_ps.
  now rewrite bytes_of_pstring_of_bs by exact Hs.
Qed.

Theorem decode_bs_of_pstring c s :
  decode_bs c (bs_of_pstring s) = option_map BS.parse (decode c (bytes_of_pstring s)).
Proof.
  unfold decode_bs, bs_of_pstring. now rewrite print_parse.
Qed.

(** ** Normalising tactic

    [base64_simpl] rewrites away the representation conversions, leaving a goal
    stated purely in terms of [Base64.encode] and [Base64.decode] on byte
    lists, where [decode_encode] and [encode_decode] apply. *)

#[export] Hint Rewrite pstring_of_bs_of_pstring decode_bs_of_pstring : base64.

Ltac base64_simpl :=
  autorewrite with base64 in *;
  (* the database produces [option_map _ (decode _ _)]; reducing [option_map]
     is what lets a second pass see through a [Some] once the caller has
     rewritten with [decode_encode]. *)
  cbn [option_map] in *;
  autorewrite with base64 in *.

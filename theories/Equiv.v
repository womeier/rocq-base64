(** * Agreement between the four representations

    [Base64], [MetaRocqString], [StdStrings] and [PrimStrings] each define an
    encoder and a decoder, on [list byte], on MetaRocq bytestrings, on
    standard library strings and on primitive strings respectively. This file
    shows they are all the same function viewed through the conversions, so a
    result proved in one representation transfers to the others.

    It also collects the rewrite databases. [base64_simpl] normalises a goal
    about any of the four representations into a goal about byte lists. *)

From Stdlib Require Import Strings.Byte Strings.String Lists.List.
From Stdlib Require Import ZArith Lia.
From Stdlib Require Import Numbers.Cyclic.Int63.Uint63.
From Stdlib Require Strings.PrimString Strings.PrimStringAxioms Strings.PString.
From Base64 Require Import Util Sextet Alphabet Base64.
From Base64 Require Import MetaRocqString StdStrings PrimStrings.
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

(** ** Converting directly between strings and primitive strings *)

Definition pstring_of_str (s : string) : pstring :=
  pstring_of_bytes (list_byte_of_string s).

Definition str_of_pstring (s : pstring) : string :=
  string_of_list_byte (bytes_of_pstring s).

Lemma pstring_of_str_of_pstring s : pstring_of_str (str_of_pstring s) = s.
Proof.
  unfold pstring_of_str, str_of_pstring.
  rewrite list_byte_of_string_of_list_byte.
  apply pstring_of_bytes_of_pstring.
Qed.

Lemma str_of_pstring_of_str s :
  (Z.of_nat (String.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  str_of_pstring (pstring_of_str s) = s.
Proof.
  intros Hlen. unfold pstring_of_str, str_of_pstring.
  rewrite bytes_of_pstring_of_bytes by (now rewrite length_list_byte_of_string).
  apply string_of_list_byte_of_string.
Qed.

Lemma bytes_of_pstring_of_str s :
  (Z.of_nat (String.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  bytes_of_pstring (pstring_of_str s) = list_byte_of_string s.
Proof.
  intros Hlen. unfold pstring_of_str.
  now rewrite bytes_of_pstring_of_bytes by (now rewrite length_list_byte_of_string).
Qed.

Lemma length_pstring_of_str s :
  (Z.of_nat (String.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  Uint63.to_Z (PrimString.length (pstring_of_str s)) = Z.of_nat (String.length s).
Proof.
  intros Hlen. rewrite <- (length_bytes_of_pstring (pstring_of_str s)).
  rewrite bytes_of_pstring_of_str by exact Hlen.
  now rewrite length_list_byte_of_string.
Qed.

(** ** Converting directly between bytestrings and strings

    Both are inductive lists of bytes, so this pair is inverse in both
    directions with no side condition. *)

Definition str_of_bs (s : BS.t) : string := string_of_list_byte (BS.print s).
Definition bs_of_str (s : string) : BS.t := BS.parse (list_byte_of_string s).

Lemma str_of_bs_of_str s : str_of_bs (bs_of_str s) = s.
Proof.
  unfold str_of_bs, bs_of_str. rewrite print_parse.
  apply string_of_list_byte_of_string.
Qed.

Lemma bs_of_str_of_bs s : bs_of_str (str_of_bs s) = s.
Proof.
  unfold str_of_bs, bs_of_str. rewrite list_byte_of_string_of_list_byte.
  apply parse_print.
Qed.

(** ** The encoders agree

    All four encoders are the core [encode] conjugated by the relevant
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

Theorem encode_ps_of_str c s :
  (Z.of_nat (String.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_ps c (pstring_of_str s) = pstring_of_str (encode_str c s).
Proof.
  intros Hs. unfold encode_ps, pstring_of_str.
  rewrite bytes_of_pstring_of_bytes by (now rewrite length_list_byte_of_string).
  now rewrite list_byte_of_string_encode_str.
Qed.

Theorem encode_str_of_pstring c s :
  (Z.of_nat (length (encode c (bytes_of_pstring s)))
     <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_str c (str_of_pstring s) = str_of_pstring (encode_ps c s).
Proof.
  intros Hlen. unfold str_of_pstring, encode_str, encode_ps.
  rewrite list_byte_of_string_of_list_byte. f_equal. symmetry.
  now apply bytes_of_pstring_of_bytes.
Qed.

Theorem encode_str_of_bs c s : encode_str c (str_of_bs s) = str_of_bs (encode_bs c s).
Proof.
  unfold encode_str, str_of_bs.
  rewrite list_byte_of_string_of_list_byte. now rewrite print_encode_bs.
Qed.

Theorem encode_bs_of_str c s : encode_bs c (bs_of_str s) = bs_of_str (encode_str c s).
Proof.
  unfold encode_bs, bs_of_str.
  rewrite print_parse. now rewrite list_byte_of_string_encode_str.
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

Theorem decode_ps_of_str c s :
  (Z.of_nat (String.length s) <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (pstring_of_str s)
  = option_map pstring_of_bytes (decode c (list_byte_of_string s)).
Proof.
  intros Hs. unfold decode_ps.
  now rewrite bytes_of_pstring_of_str by exact Hs.
Qed.

Theorem decode_str_of_pstring c s :
  decode_str c (str_of_pstring s)
  = option_map string_of_list_byte (decode c (bytes_of_pstring s)).
Proof.
  unfold decode_str, str_of_pstring.
  now rewrite list_byte_of_string_of_list_byte.
Qed.

Theorem decode_str_of_bs c s :
  decode_str c (str_of_bs s) = option_map string_of_list_byte (decode c (BS.print s)).
Proof.
  unfold decode_str, str_of_bs. now rewrite list_byte_of_string_of_list_byte.
Qed.

Theorem decode_bs_of_str c s :
  decode_bs c (bs_of_str s) = option_map BS.parse (decode c (list_byte_of_string s)).
Proof.
  unfold decode_bs, bs_of_str. now rewrite print_parse.
Qed.

(** ** Normalising tactic

    [base64_simpl] rewrites away the representation conversions, leaving a goal
    stated purely in terms of [Base64.encode] and [Base64.decode] on byte
    lists, where [decode_encode] and [encode_decode] apply.

    The [base64] database holds the unfolding equations ([encode_bs_eq],
    [encode_str_eq], [decode_ps_eq], …), the conversion-elimination lemmas
    ([print_parse], [parse_print], [list_byte_of_string_of_list_byte],
    [pstring_of_bytes_of_pstring], [pstring_of_bs_of_pstring], …) and the
    commutation lemmas ([print_encode_bs], [encode_bs_parse],
    [list_byte_of_string_encode_str], [decode_bs_of_pstring], …).

    A roundtrip over bytestrings then goes:

<<
    Goal forall c s, wf c -> decode_bs c (encode_bs c s) = Some s.
    Proof.
      intros c s Hwf. base64_simpl.
      rewrite decode_encode by exact Hwf. base64_simpl. reflexivity.
    Qed.
>>

    The same script works over standard library strings, and over primitive
    strings with the [max_length] bound as the only remaining obligation:

<<
    Goal forall c s,
      wf c ->
      (Z.of_nat (length (encode c (bytes_of_pstring s)))
         <= Uint63.to_Z PrimString.max_length)%Z ->
      decode_ps c (encode_ps c s) = Some s.
    Proof.
      intros c s Hwf Hlen. base64_simpl.
      rewrite bytes_of_pstring_of_bytes by exact Hlen.
      rewrite decode_encode by exact Hwf. base64_simpl. reflexivity.
    Qed.
>>

    All three are already proved, as [MetaRocqString.decode_bs_encode_bs],
    [StdStrings.decode_str_encode_str] and [PrimStrings.decode_ps_encode_ps];
    they are shown here as the shape a user's own proof takes. *)

#[export] Hint Rewrite
  pstring_of_bs_of_pstring pstring_of_str_of_pstring
  str_of_bs_of_str bs_of_str_of_bs
  decode_bs_of_pstring decode_str_of_pstring
  decode_str_of_bs decode_bs_of_str : base64.

Ltac base64_simpl :=
  autorewrite with base64 in *;
  (* the database produces [option_map _ (decode _ _)]; reducing [option_map]
     is what lets a second pass see through a [Some] once the caller has
     rewritten with [decode_encode]. *)
  cbn [option_map] in *;
  autorewrite with base64 in *.

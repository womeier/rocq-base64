(** * Base64 on standard library strings

    [Stdlib.Strings.String] represents a string as an inductive list of
    [ascii]. It already comes with [list_byte_of_string] and
    [string_of_list_byte] mapping to and from [list byte], mutually inverse in
    both directions, so base64 on strings is the core development transported
    along that pair.

    Every lemma below is oriented so that rewriting with it moves
    [list_byte_of_string] inwards and leaves a goal about [list byte] -- see
    the [base64] rewrite database at the end of the file. *)

From Stdlib Require Import Strings.Byte Strings.Ascii Strings.String.
From Stdlib Require Import Lists.List Arith.PeanoNat.
From Base64 Require Import Sextet Alphabet Base64.
Import ListNotations.

(** ** The two conversions are mutually inverse

    Both directions are in the standard library ([string_of_list_byte_of_string]
    and [list_byte_of_string_of_list_byte]); what is missing is how the
    conversion interacts with length and concatenation. Both conversions are
    [map]s over the [ascii] list underlying a string, so both are inductions. *)

Lemma length_list_byte_of_string s :
  List.length (list_byte_of_string s) = String.length s.
Proof.
  cbv [list_byte_of_string]. induction s as [|a s IH]; cbn; congruence.
Qed.

Lemma list_byte_of_string_append s t :
  list_byte_of_string (String.append s t)
  = list_byte_of_string s ++ list_byte_of_string t.
Proof.
  cbv [list_byte_of_string]. induction s as [|a s IH]; cbn; congruence.
Qed.

Lemma string_of_list_byte_app l1 l2 :
  string_of_list_byte (l1 ++ l2)
  = String.append (string_of_list_byte l1) (string_of_list_byte l2).
Proof.
  cbv [string_of_list_byte]. induction l1 as [|b l1 IH]; cbn; congruence.
Qed.

(** ** Encoding and decoding strings *)

Definition encode_str (c : config) (s : string) : string :=
  string_of_list_byte (encode c (list_byte_of_string s)).

Definition decode_str (c : config) (s : string) : option string :=
  option_map string_of_list_byte (decode c (list_byte_of_string s)).

(** ** Pushing the conversions through

    These are the equations to rewrite with: each one replaces an operation on
    strings by the corresponding operation on byte lists. *)

Lemma encode_str_eq c s :
  encode_str c s = string_of_list_byte (encode c (list_byte_of_string s)).
Proof. reflexivity. Qed.

Lemma decode_str_eq c s :
  decode_str c s = option_map string_of_list_byte (decode c (list_byte_of_string s)).
Proof. reflexivity. Qed.

Lemma list_byte_of_string_encode_str c s :
  list_byte_of_string (encode_str c s) = encode c (list_byte_of_string s).
Proof. unfold encode_str. apply list_byte_of_string_of_list_byte. Qed.

Lemma list_byte_of_string_decode_str c s :
  option_map list_byte_of_string (decode_str c s) = decode c (list_byte_of_string s).
Proof.
  unfold decode_str.
  destruct (decode c (list_byte_of_string s)) as [bs|]; cbn; [|reflexivity].
  now rewrite list_byte_of_string_of_list_byte.
Qed.

Lemma encode_str_of_list_byte c l :
  encode_str c (string_of_list_byte l) = string_of_list_byte (encode c l).
Proof. unfold encode_str. now rewrite list_byte_of_string_of_list_byte. Qed.

Lemma decode_str_of_list_byte c l :
  decode_str c (string_of_list_byte l) = option_map string_of_list_byte (decode c l).
Proof. unfold decode_str. now rewrite list_byte_of_string_of_list_byte. Qed.

(** ** The roundtrip theorems, transported *)

Theorem decode_str_encode_str c s : wf c -> decode_str c (encode_str c s) = Some s.
Proof.
  intros Hwf. unfold decode_str, encode_str.
  rewrite list_byte_of_string_of_list_byte.
  rewrite (decode_encode c (list_byte_of_string s) Hwf). cbn.
  now rewrite string_of_list_byte_of_string.
Qed.

Theorem encode_str_decode_str c s t :
  wf c -> decode_str c s = Some t -> encode_str c t = s.
Proof.
  intros Hwf H. unfold decode_str in H. unfold encode_str.
  destruct (decode c (list_byte_of_string s)) as [bs|] eqn:Hd; cbn in H; [|discriminate].
  injection H as <-. rewrite list_byte_of_string_of_list_byte.
  rewrite (encode_decode c (list_byte_of_string s) bs Hwf Hd).
  apply string_of_list_byte_of_string.
Qed.

Corollary decode_str_encode_str_iff c s t :
  wf c -> decode_str c s = Some t <-> encode_str c t = s.
Proof.
  intros Hwf. split; [now apply encode_str_decode_str|].
  intros <-. now apply decode_str_encode_str.
Qed.

Corollary encode_str_inj c s t : wf c -> encode_str c s = encode_str c t -> s = t.
Proof.
  intros Hwf Heq.
  assert (Some s = Some t) as H by
    (rewrite <- (decode_str_encode_str c s Hwf), <- (decode_str_encode_str c t Hwf), Heq;
     reflexivity).
  now injection H as <-.
Qed.

(** ** Length and compositionality *)

Lemma length_encode_str c s :
  String.length (encode_str c s) = List.length (encode c (list_byte_of_string s)).
Proof.
  unfold encode_str.
  now rewrite <- length_list_byte_of_string, list_byte_of_string_of_list_byte.
Qed.

Corollary length_encode_str_spec c s :
  String.length (encode_str c s) =
  if pad c then 4 * ((String.length s + 2) / 3)
  else 4 * (String.length s / 3) + match String.length s mod 3 with
                                   | 0 => 0
                                   | 1 => 2
                                   | _ => 3
                                   end.
Proof.
  rewrite length_encode_str, encode_length, length_list_byte_of_string. reflexivity.
Qed.

Theorem encode_str_append c s t :
  String.length s mod 3 = 0 ->
  encode_str c (String.append s t)
  = String.append (encode_str c s) (encode_str c t).
Proof.
  intros Hlen. unfold encode_str.
  rewrite list_byte_of_string_append, encode_app
    by (now rewrite length_list_byte_of_string).
  apply string_of_list_byte_app.
Qed.

(** ** Rewrite database

    [autorewrite with base64] turns a goal about strings into a goal about
    byte lists, where the core theory applies. *)

(* [encode_str_eq] and [decode_str_eq] are what make the database normalizing
   rather than merely simplifying: without them an [encode_str c s] on an
   opaque [s] has no rewrite to fire, and a goal like
   [decode_str c (encode_str c s) = Some s] is left untouched.  With them it
   unfolds to the core operations under the two conversions, which
   [list_byte_of_string_of_list_byte] then collapses. *)
#[export] Hint Rewrite encode_str_eq decode_str_eq
  list_byte_of_string_of_list_byte string_of_list_byte_of_string
  list_byte_of_string_append length_list_byte_of_string
  list_byte_of_string_encode_str list_byte_of_string_decode_str
  encode_str_of_list_byte decode_str_of_list_byte : base64.

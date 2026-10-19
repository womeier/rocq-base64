(** * The standard library string instance

    Base64 operations and their correctness proofs are provided by [ByteString].
    The standard library supplies mutually inverse byte conversions; this
    module adds their length and append laws and the resulting instance. *)

From Stdlib Require Import Strings.Byte Strings.Ascii Strings.String.
From Stdlib Require Import Lists.List Arith.PeanoNat.
From Base64 Require Import Alphabet.
From Base64 Require ByteString.
Import ListNotations.

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

#[export] Instance string_bytestring : ByteString.ByteString string := {
  ByteString.to_bytes := list_byte_of_string;
  ByteString.of_bytes := string_of_list_byte;
  ByteString.fits _ := True;
  ByteString.of_to_bytes := string_of_list_byte_of_string;
  ByteString.to_of_bytes bs _ := list_byte_of_string_of_list_byte bs;
  ByteString.fits_to_bytes _ := I;
  ByteString.fits_shorter _ _ _ _ := I
}.

Theorem string_encode_length c (s : string) :
  String.length (ByteString.encode c s) =
  if pad c then 4 * ((String.length s + 2) / 3)
  else 4 * (String.length s / 3) + match String.length s mod 3 with
                                   | 0 => 0
                                   | 1 => 2
                                   | _ => 3
                                   end.
Proof.
  rewrite <- !length_list_byte_of_string.
  exact (@ByteString.encode_length string string_bytestring c s I).
Qed.

(** [ByteString.append] is the standard library's own concatenation. *)
Lemma append_string (s t : string) :
  ByteString.append s t = String.append s t.
Proof.
  change (string_of_list_byte (list_byte_of_string s ++ list_byte_of_string t)
          = String.append s t).
  rewrite <- list_byte_of_string_append.
  apply string_of_list_byte_of_string.
Qed.

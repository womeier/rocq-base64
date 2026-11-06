(** * README example: byte lists *)

From Base64 Require Import All.
From Stdlib Require Import Strings.String.   (* for list_byte_of_string *)

Example encode_sentence :
  encode standard (list_byte_of_string "the quick brown fox jumps")
  = list_byte_of_string "dGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcw==".
Proof. reflexivity. Qed.

Example decode_foob :
  decode url (list_byte_of_string "Zm9vYg")
  = Some (list_byte_of_string "foob").
Proof. reflexivity. Qed.

(** The core functions on [list byte] stay reachable under the [Base64]
    prefix, as the README claims. *)
Example core_still_reachable :
  Base64.encode standard (list_byte_of_string "foobar")
  = list_byte_of_string "Zm9vYmFy".
Proof. reflexivity. Qed.

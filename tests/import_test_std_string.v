(** * README example: standard library strings *)

From Base64 Require Import All.
From Stdlib Require Import Strings.String.

Example encode_foobar : encode standard "foobar"%string = "Zm9vYmFy"%string.
Proof. reflexivity. Qed.

Example decode_foob : decode url "Zm9vYg"%string = Some "foob"%string.
Proof. reflexivity. Qed.

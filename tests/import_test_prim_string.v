(** * README example: primitive strings *)

From Base64 Require Import All.
From Stdlib Require Import Strings.PrimString.

Example encode_foobar : encode standard "foobar"%pstring = "Zm9vYmFy"%pstring.
Proof. vm_compute. reflexivity. Qed.

Example decode_foob : decode url "Zm9vYg"%pstring = Some "foob"%pstring.
Proof. vm_compute. reflexivity. Qed.

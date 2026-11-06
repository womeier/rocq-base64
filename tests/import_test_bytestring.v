(** * README example: MetaRocq bytestrings *)

From Base64 Require Import All.
From Base64 Require Import InstanceBytestring.
Import MetaRocq.Utils.bytestring.

Example encode_foobar : encode standard "foobar"%bs = "Zm9vYmFy"%bs.
Proof. reflexivity. Qed.

Example decode_foobar : decode standard "Zm9vYmFy"%bs = Some "foobar"%bs.
Proof. reflexivity. Qed.

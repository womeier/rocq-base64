(** * Test vectors for the MetaRocq bytestring bridge

    Counterpart to [Base64.Tests], for the bridge kept out of the installed
    package (see [InstanceBytestring.v]). *)

From Stdlib Require Import Strings.Byte Strings.String Lists.List.
From Base64 Require Import All.
From Base64.MetaRocq Require Import InstanceBytestring.
Import ListNotations.

Definition bs (x : String.string) : BS.t := BS.parse (list_byte_of_string x).

Example encode_bs_foobar : encode standard (bs "foobar") = bs "Zm9vYmFy".
Proof. reflexivity. Qed.
Example encode_bs_foob : encode standard (bs "foob") = bs "Zm9vYg==".
Proof. reflexivity. Qed.
Example decode_bs_foob : decode standard (bs "Zm9vYg==") = Some (bs "foob").
Proof. reflexivity. Qed.
Example decode_bs_reject : decode standard (bs "QR==") = None.
Proof. reflexivity. Qed.

Example roundtrip_bs c s :
  wf_config c -> decode c (encode c s) = Some (s : BS.t).
Proof.
  intros Hwf. exact (@ByteString.decode_encode BS.t metarocq_bytestring c s Hwf I).
Qed.

Example append_bs_foobar :
  encode standard (ByteString.append (bs "foo") (bs "bar")) =
  ByteString.append (encode standard (bs "foo")) (encode standard (bs "bar")).
Proof. reflexivity. Qed.

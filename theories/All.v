(** * rocq-base64

    Importing this module brings in the whole library: the generic
    [ByteString] API, its instances over byte lists, standard library strings
    and Rocq's primitive strings, together with their shared correctness
    proofs. [Base64] itself (the core algorithm on [list byte]) is required
    but deliberately not exported here, so that the bare names [encode],
    [decode], etc. unambiguously mean the generic [ByteString] versions;
    reach the core ones by writing [Base64.encode] and so on.

    The test vectors in [Base64.Tests] are deliberately not re-exported. *)

From Base64 Require Util Sextet.
From Base64 Require Export Alphabet ByteString InstanceStdString InstancePrimString.

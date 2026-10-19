(** * rocq-base64

    Importing this module brings in the whole library: base64 over byte lists,
    over MetaRocq bytestrings and over Rocq's primitive strings, together with
    the lemmas relating the three.

    The test vectors in [Base64.Tests] are deliberately not re-exported. *)

From Base64 Require Export Util Sextet Alphabet Base64 MetaRocqString PrimStrings Equiv.

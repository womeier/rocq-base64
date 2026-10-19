(** * rocq-base64

    Importing this module brings in the whole library: base64 over byte lists,
    over MetaRocq bytestrings, over standard library strings and over Rocq's
    primitive strings, together with the lemmas relating the four.

    The test vectors in [Base64.Tests] are deliberately not re-exported. *)

From Base64 Require Export Util Sextet Alphabet Base64
  MetaRocqString StdStrings PrimStrings Equiv.

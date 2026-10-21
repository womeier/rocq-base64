(** * Extraction for differential testing

    Extracts the core encoder and decoder to OCaml so they can be run against
    an independent implementation. This file is not part of the library build;
    see [tests/run.sh].

    Only the core is extracted, deliberately. The algorithm is the part an
    independent implementation can disagree with; the [ByteString] instances
    on top of it are proved equal to the core in Rocq ([ByteString.encode] is
    [of_bytes] after [Base64.encode] after [to_bytes], and for [list byte]
    those conversions are the identity), so extracting them would re-test the
    same bytes through a wrapper that carries its own proof.

    [nat] is left as unary Peano numbers. The library only ever uses it for
    values below 64 (sextet values and alphabet indices), so the cost is
    irrelevant here, and keeping the default extraction avoids relying on the
    [ExtrOcamlNatInt] axioms being sound for this code. Bytes are converted on
    the OCaml side via [byte_to_nat] / [byte_of_nat]. *)

From Stdlib Require Import extraction.Extraction.
From Stdlib Require Import extraction.ExtrOcamlBasic.
From Stdlib Require Import Strings.Byte.
From Base64 Require Import Alphabet Base64.

Definition byte_to_nat := Byte.to_nat.
Definition byte_of_nat := Byte.of_nat.

Extraction Language OCaml.
Set Extraction Output Directory "tests/extracted".

Separate Extraction
  encode decode
  standard url url_padded
  byte_to_nat byte_of_nat.

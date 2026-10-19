(** * Extraction for differential testing

    Extracts the core encoder and decoder to OCaml so they can be run against
    an independent implementation. This file is not part of the library build;
    see [tests/run.sh].

    [nat] is left as unary Peano numbers. The library only ever uses it for
    values below 64 (sextet values and alphabet indices), so the cost is
    irrelevant here, and keeping the default extraction avoids relying on the
    [ExtrOcamlNatInt] axioms being sound for this code. Bytes are converted on
    the OCaml side via [byte_to_nat] / [byte_of_nat]. *)

From Stdlib Require Import extraction.Extraction.
From Stdlib Require Import extraction.ExtrOcamlBasic.
From Stdlib Require Import Strings.Byte.
From base64 Require Import Alphabet Base64.

Definition byte_to_nat := Byte.to_nat.
Definition byte_of_nat := Byte.of_nat.

Extraction Language OCaml.
Set Extraction Output Directory "tests/extracted".

Separate Extraction
  encode decode
  standard url url_padded
  byte_to_nat byte_of_nat.

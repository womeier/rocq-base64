(** * The MetaRocq bytestring instance

    Base64 operations and their correctness proofs are provided by [Strings].
    This module supplies the byte conversions and relates the generic length
    result to MetaRocq's native length. *)

From Stdlib Require Import Strings.Byte Lists.List Arith.PeanoNat.
From MetaRocq.Utils Require bytestring.
From Base64 Require Import Alphabet.
From Base64 Require Strings.
Import ListNotations.

(** MetaRocq's [String] module would otherwise shadow the standard library's. *)
Module BS := MetaRocq.Utils.bytestring.String.

Lemma print_parse (l : list byte) : BS.print (BS.parse l) = l.
Proof. induction l as [|b l IH]; cbn; congruence. Qed.

Lemma parse_print (s : BS.t) : BS.parse (BS.print s) = s.
Proof. apply BS.print_parse_inv. Qed.

Lemma print_append (s t : BS.t) :
  BS.print (BS.append s t) = BS.print s ++ BS.print t.
Proof. induction s as [|b s IH]; cbn; congruence. Qed.

Lemma print_length (s : BS.t) : length (BS.print s) = BS.length s.
Proof. induction s as [|b s IH]; cbn; congruence. Qed.

#[export] Instance bytestring_base64 : Strings.ByteString BS.t := {
  Strings.to_bytes := BS.print;
  Strings.of_bytes := BS.parse;
  Strings.fits _ := True;
  Strings.of_to_bytes := parse_print;
  Strings.to_of_bytes bs _ := print_parse bs;
  Strings.fits_to_bytes _ := I;
  Strings.fits_shorter _ _ _ _ := I
}.

Theorem encode_length c (s : BS.t) :
  BS.length (Strings.encode c s) =
  if pad c then 4 * ((BS.length s + 2) / 3)
  else 4 * (BS.length s / 3) + match BS.length s mod 3 with
                               | 0 => 0
                               | 1 => 2
                               | _ => 3
                               end.
Proof.
  rewrite <- !print_length.
  exact (@Strings.encode_length BS.t bytestring_base64 c s I).
Qed.

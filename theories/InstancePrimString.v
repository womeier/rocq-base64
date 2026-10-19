(** * Base64 on primitive strings

    Rocq's primitive strings are arrays of [char63], a 63-bit integer
    constrained to a byte's range. [PrimStringAxioms] relates them to
    [list char63], so base64 on primitive strings is the core development
    transported along a byte / [char63] conversion.

    Unlike the byte-list and standard-string instances, this one is not
    unconditional: a primitive string cannot be longer than [max_length], and
    encoding grows its input by a third. So the statements that build a string
    carry a length side condition, while those that only consume one do not --
    a primitive string that already exists is within bounds by
    [PString.valid_length]. *)

From Stdlib Require Import Strings.Byte Lists.List.
From Stdlib Require Import ZArith Lia.
From Stdlib Require Import Numbers.Cyclic.Int63.Uint63.
From Stdlib Require Strings.PrimString Strings.PrimStringAxioms Strings.PString.
From Base64 Require Import Sextet Alphabet Base64.
From Base64 Require ByteString.
Import ListNotations.

Notation pstring := PrimString.string.
Local Notation char63 := PrimString.char63.

(** ** Bytes and [char63] *)

Definition char63_of_byte (b : byte) : char63 :=
  Uint63.of_Z (Z.of_N (Byte.to_N b)).

Definition byte_of_char63 (c : char63) : byte :=
  match Byte.of_N (Z.to_N (Uint63.to_Z (c land 255)%uint63)) with
  | Some b => b
  | None => Byte.x00   (** unreachable for valid [char63] *)
  end.

Lemma byte_of_char63_of_byte b : byte_of_char63 (char63_of_byte b) = b.
Proof. destruct b; vm_compute; reflexivity. Qed.

Lemma char63_of_byte_valid b :
  PrimStringAxioms.char63_valid (char63_of_byte b).
Proof. destruct b; vm_compute; reflexivity. Qed.

(** A valid [char63] is below 256, which is what makes the conversion back to
    a byte total. *)
Lemma char63_valid_lt c :
  PrimStringAxioms.char63_valid c -> (0 <= Uint63.to_Z c < 256)%Z.
Proof.
  unfold PrimStringAxioms.char63_valid. intros Hv.
  pose proof (Uint63.to_Z_bounded c) as [Hlo _].
  assert (Uint63.to_Z (c land 255)%uint63 = Uint63.to_Z c) as H by (now rewrite Hv).
  rewrite Uint63.land_spec' in H.
  replace (Uint63.to_Z 255%uint63) with (Z.ones 8) in H by reflexivity.
  rewrite Z.land_ones in H by lia.
  pose proof (Z.mod_pos_bound (Uint63.to_Z c) (2 ^ 8) ltac:(lia)).
  rewrite H in *. lia.
Qed.

Lemma char63_of_byte_of_char63 c :
  PrimStringAxioms.char63_valid c -> char63_of_byte (byte_of_char63 c) = c.
Proof.
  intros Hv. pose proof (char63_valid_lt c Hv) as [Hlo Hhi].
  unfold PrimStringAxioms.char63_valid in Hv.
  unfold char63_of_byte, byte_of_char63. rewrite Hv.
  destruct (Byte.of_N (Z.to_N (Uint63.to_Z c))) as [b|] eqn:Hb.
  - apply Byte.to_of_N in Hb. rewrite Hb, Z2N.id by exact Hlo.
    apply Uint63.of_to_Z.
  - exfalso. apply Byte.of_N_None_iff in Hb.
    apply N2Z.inj_lt in Hb. rewrite Z2N.id in Hb by exact Hlo.
    replace (Z.of_N 255) with 255%Z in Hb by reflexivity. lia.
Qed.

(** ** Primitive strings and byte lists *)

Definition bytes_of_pstring (s : pstring) : list byte :=
  map byte_of_char63 (PrimStringAxioms.to_list s).

Definition pstring_of_bytes (bs : list byte) : pstring :=
  PrimStringAxioms.of_list (map char63_of_byte bs).

(** Every [char63] of an existing string is valid, so converting its bytes back
    recovers the string's own [char63] list. *)
Lemma map_char63_bytes_of_pstring s :
  map char63_of_byte (bytes_of_pstring s) = PrimStringAxioms.to_list s.
Proof.
  unfold bytes_of_pstring. rewrite map_map.
  rewrite (map_ext_in _ id); [|intros a Ha; apply char63_of_byte_of_char63].
  - apply map_id.
  - eapply (proj1 (Forall_forall _ _)); [|exact Ha].
    apply PrimStringAxioms.to_list_char63_valid.
Qed.

Lemma pstring_of_bytes_of_pstring s : pstring_of_bytes (bytes_of_pstring s) = s.
Proof.
  unfold pstring_of_bytes. rewrite map_char63_bytes_of_pstring.
  apply PrimStringAxioms.of_to_list.
Qed.

Lemma bytes_of_pstring_of_bytes bs :
  (Z.of_nat (length bs) <= Uint63.to_Z PrimString.max_length)%Z ->
  bytes_of_pstring (pstring_of_bytes bs) = bs.
Proof.
  intros Hlen. unfold bytes_of_pstring, pstring_of_bytes.
  rewrite PString.to_of_list.
  - rewrite map_map, (map_ext _ id) by apply byte_of_char63_of_byte.
    apply map_id.
  - apply Forall_map, Forall_forall. intros b _. apply char63_of_byte_valid.
  - now rewrite length_map.
Qed.

Lemma length_bytes_of_pstring s :
  Z.of_nat (length (bytes_of_pstring s)) = Uint63.to_Z (PrimString.length s).
Proof.
  unfold bytes_of_pstring. rewrite length_map.
  symmetry. apply PString.length_spec_Z.
Qed.

(** ** The bounded string instance *)

(** A primitive string that already exists is within bounds, so its bytes
    always fit. *)
Lemma pstring_fits_to_bytes (s : pstring) :
  (Z.of_nat (length (bytes_of_pstring s)) <= Uint63.to_Z PrimString.max_length)%Z.
Proof. rewrite length_bytes_of_pstring. apply PString.valid_length. Qed.

Lemma pstring_fits_shorter (xs ys : list byte) :
  length xs <= length ys ->
  (Z.of_nat (length ys) <= Uint63.to_Z PrimString.max_length)%Z ->
  (Z.of_nat (length xs) <= Uint63.to_Z PrimString.max_length)%Z.
Proof. lia. Qed.

#[export] Instance pstring_bytestring : ByteString.ByteString pstring := {
  ByteString.to_bytes := bytes_of_pstring;
  ByteString.of_bytes := pstring_of_bytes;
  ByteString.fits bs :=
    (Z.of_nat (length bs) <= Uint63.to_Z PrimString.max_length)%Z;
  ByteString.of_to_bytes := pstring_of_bytes_of_pstring;
  ByteString.to_of_bytes := bytes_of_pstring_of_bytes;
  ByteString.fits_to_bytes := pstring_fits_to_bytes;
  ByteString.fits_shorter := pstring_fits_shorter
}.

(** A sufficient capacity condition expressed using the native input length.
    Use this to discharge [fits] in the shared correctness theorems. *)
Lemma encode_fits c s :
  (2 * Uint63.to_Z (PrimString.length s) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  ByteString.fits (S := pstring) (encode c (bytes_of_pstring s)).
Proof.
  intros Hlen. change
    (Z.of_nat (length (encode c (bytes_of_pstring s)))
       <= Uint63.to_Z PrimString.max_length)%Z.
  pose proof (encode_length_le c (bytes_of_pstring s)) as Hle.
  apply (Z.le_trans _ (Z.of_nat (2 * length (bytes_of_pstring s) + 4))); [lia|].
  rewrite Nat2Z.inj_add, Nat2Z.inj_mul, length_bytes_of_pstring.
  replace (Z.of_nat 2) with 2%Z by reflexivity.
  replace (Z.of_nat 4) with 4%Z by reflexivity.
  lia.
Qed.

(** ** Length *)

(** The side condition is the same capacity bound on the *input* that
    [encode_fits] takes, rather than one on the encoded output: a caller knows
    the length of the string it holds, not of the string it is about to
    build. *)
Lemma pstring_encode_length c s :
  (2 * Uint63.to_Z (PrimString.length s) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  Uint63.to_Z (PrimString.length (ByteString.encode c s))
  = Z.of_nat (length (encode c (bytes_of_pstring s))).
Proof.
  intros Hlen. rewrite <- length_bytes_of_pstring.
  exact (f_equal (fun bs => Z.of_nat (length bs))
    (@ByteString.to_bytes_encode pstring pstring_bytestring c s
       (encode_fits c s Hlen))).
Qed.

(** ** Concatenation *)

(** [ByteString.append] is the native [PrimString.cat], but only within
    capacity: [cat] truncates at [max_length], so unlike the byte-list and
    standard-string instances this agreement is not unconditional -- two
    strings that each fit need not concatenate to one that does. The side
    condition is on the inputs, as for [encode_fits]. *)
Lemma append_pstring (s t : pstring) :
  (Uint63.to_Z (PrimString.length s) + Uint63.to_Z (PrimString.length t)
     <= Uint63.to_Z PrimString.max_length)%Z ->
  ByteString.append s t = PrimString.cat s t.
Proof.
  intros Hlen.
  change (pstring_of_bytes (bytes_of_pstring s ++ bytes_of_pstring t)
          = PrimString.cat s t).
  unfold pstring_of_bytes. rewrite map_app, !map_char63_bytes_of_pstring.
  rewrite <- PString.to_list_cat by exact Hlen.
  apply PrimStringAxioms.of_to_list.
Qed.

(** * Base64 on primitive strings

    Rocq's primitive strings are arrays of [char63], a 63-bit integer
    constrained to a byte's range. [PrimStringAxioms] relates them to
    [list char63], so base64 on primitive strings is the core development
    transported along a byte / [char63] conversion.

    Unlike the bytestring bridge, this one is not unconditional: a primitive
    string cannot be longer than [max_length], and encoding grows its input by
    a third. So the statements that build a string carry a length side
    condition, while those that only consume one do not -- a primitive string
    that already exists is within bounds by [PString.valid_length]. *)

From Stdlib Require Import Strings.Byte Lists.List.
From Stdlib Require Import ZArith Lia.
From Stdlib Require Import Numbers.Cyclic.Int63.Uint63.
From Stdlib Require Strings.PrimString Strings.PrimStringAxioms Strings.PString.
From base64 Require Import Sextet Alphabet Base64.
Import ListNotations.

Notation pstring := PrimString.string.
Notation char63 := PrimString.char63.

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

Lemma pstring_of_bytes_of_pstring s : pstring_of_bytes (bytes_of_pstring s) = s.
Proof.
  unfold pstring_of_bytes, bytes_of_pstring. rewrite map_map.
  rewrite (map_ext_in _ id); [|intros a Ha; apply char63_of_byte_of_char63].
  - rewrite map_id. apply PrimStringAxioms.of_to_list.
  - eapply (proj1 (Forall_forall _ _)); [|exact Ha].
    apply PrimStringAxioms.to_list_char63_valid.
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

(** ** Encoding and decoding primitive strings *)

Definition encode_ps (c : config) (s : pstring) : pstring :=
  pstring_of_bytes (encode c (bytes_of_pstring s)).

Definition decode_ps (c : config) (s : pstring) : option pstring :=
  option_map pstring_of_bytes (decode c (bytes_of_pstring s)).

(** ** Pushing the conversions through *)

Lemma encode_ps_eq c s :
  encode_ps c s = pstring_of_bytes (encode c (bytes_of_pstring s)).
Proof. reflexivity. Qed.

Lemma decode_ps_eq c s :
  decode_ps c s = option_map pstring_of_bytes (decode c (bytes_of_pstring s)).
Proof. reflexivity. Qed.

Lemma bytes_of_pstring_encode_ps c s :
  (Z.of_nat (length (encode c (bytes_of_pstring s)))
     <= Uint63.to_Z PrimString.max_length)%Z ->
  bytes_of_pstring (encode_ps c s) = encode c (bytes_of_pstring s).
Proof. intros Hlen. unfold encode_ps. now apply bytes_of_pstring_of_bytes. Qed.

Lemma encode_ps_pstring_of_bytes c bs :
  (Z.of_nat (length bs) <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_ps c (pstring_of_bytes bs) = pstring_of_bytes (encode c bs).
Proof.
  intros Hlen. unfold encode_ps. now rewrite bytes_of_pstring_of_bytes.
Qed.

Lemma decode_ps_pstring_of_bytes c bs :
  (Z.of_nat (length bs) <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (pstring_of_bytes bs) = option_map pstring_of_bytes (decode c bs).
Proof.
  intros Hlen. unfold decode_ps. now rewrite bytes_of_pstring_of_bytes.
Qed.

(** ** The roundtrip theorems, transported *)

Theorem decode_ps_encode_ps c s :
  wf c ->
  (Z.of_nat (length (encode c (bytes_of_pstring s)))
     <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (encode_ps c s) = Some s.
Proof.
  intros Hwf Hlen. unfold decode_ps, encode_ps.
  rewrite bytes_of_pstring_of_bytes by exact Hlen.
  rewrite (decode_encode c _ Hwf). cbn.
  f_equal. apply pstring_of_bytes_of_pstring.
Qed.

(** The side condition above mentions the encoded length, which a caller does
    not have in hand. This version asks only about the input, using the fact
    that encoding at most doubles a string's length (and adds at most four). *)
Corollary decode_ps_encode_ps' c s :
  wf c ->
  (2 * Uint63.to_Z (PrimString.length s) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (encode_ps c s) = Some s.
Proof.
  intros Hwf Hlen. apply decode_ps_encode_ps; [exact Hwf|].
  pose proof (encode_length_le c (bytes_of_pstring s)) as Hle.
  apply (Z.le_trans _ (Z.of_nat (2 * length (bytes_of_pstring s) + 4))); [lia|].
  rewrite Nat2Z.inj_add, Nat2Z.inj_mul, length_bytes_of_pstring.
  replace (Z.of_nat 2) with 2%Z by reflexivity.
  replace (Z.of_nat 4) with 4%Z by reflexivity.
  lia.
Qed.

(** The other direction needs no side condition: the primitive string being
    decoded already exists, so it is within [max_length], and decoding only
    makes it shorter. *)
Theorem encode_ps_decode_ps c s t :
  wf c -> decode_ps c s = Some t -> encode_ps c t = s.
Proof.
  intros Hwf H. unfold decode_ps in H.
  destruct (decode c (bytes_of_pstring s)) as [bs|] eqn:Hd; cbn in H; [|discriminate].
  injection H as <-.
  assert (Z.of_nat (length bs) <= Uint63.to_Z PrimString.max_length)%Z as Hlen.
  { pose proof (decode_length_le c _ bs Hwf Hd) as Hle.
    pose proof (PString.valid_length s) as Hv.
    rewrite <- length_bytes_of_pstring in Hv. lia. }
  rewrite encode_ps_pstring_of_bytes by exact Hlen.
  rewrite (encode_decode c _ bs Hwf Hd).
  apply pstring_of_bytes_of_pstring.
Qed.

Corollary encode_ps_inj c s t :
  wf c ->
  (2 * Uint63.to_Z (PrimString.length s) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  (2 * Uint63.to_Z (PrimString.length t) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  encode_ps c s = encode_ps c t -> s = t.
Proof.
  intros Hwf Hs Ht Heq.
  assert (Some s = Some t) as H by
    (rewrite <- (decode_ps_encode_ps' c s Hwf Hs),
             <- (decode_ps_encode_ps' c t Hwf Ht), Heq; reflexivity).
  now injection H as <-.
Qed.

(** ** Length *)

Lemma length_encode_ps c s :
  (Z.of_nat (length (encode c (bytes_of_pstring s)))
     <= Uint63.to_Z PrimString.max_length)%Z ->
  Uint63.to_Z (PrimString.length (encode_ps c s))
  = Z.of_nat (length (encode c (bytes_of_pstring s))).
Proof.
  intros Hlen. rewrite PString.length_spec_Z.
  now rewrite <- bytes_of_pstring_encode_ps, length_bytes_of_pstring,
              PString.length_spec_Z by exact Hlen.
Qed.

(** ** Rewrite database *)

(* As on the bytestring side, the two unfolding equations are what let the
   database reach the core theory.  Note the asymmetry: [pstring_of_bytes
   (bytes_of_pstring s) = s] is unconditional and so belongs here, while the
   other direction needs a [max_length] bound and therefore cannot be a hint --
   [autorewrite] will leave a [bytes_of_pstring (pstring_of_bytes _)] for the
   caller to discharge with [bytes_of_pstring_of_bytes]. *)
#[export] Hint Rewrite encode_ps_eq decode_ps_eq
  pstring_of_bytes_of_pstring length_bytes_of_pstring : base64.

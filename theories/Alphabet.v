(** * Base64 alphabets

    RFC 4648 describes several base64 variants that differ only in the two
    characters used for values 62 and 63, and in whether the output is padded
    to a multiple of four characters. Both are captured by [config] here, so
    the entire development below is proved once and applies to every variant.

    The two variants the RFC names are provided as [standard] (section 4) and
    [url] (section 5). The latter is unpadded, matching how base64url is
    normally used in URLs and JWTs; [url_padded] is there for the rarer padded
    reading of section 5. *)

From Stdlib Require Import Strings.Byte Strings.String Lists.List.
From Stdlib Require Import Arith.PeanoNat Lia.
From Base64 Require Import Util Sextet.
Import ListNotations.

(** [Util.index_of] is generic in the equality test; these are its instances
    for bytes, so the proofs below need not carry the test and its properties
    around explicitly. *)

Lemma byte_eqb_true x y : Byte.eqb x y = true -> x = y.
Proof. apply Byte.byte_dec_bl. Qed.

Lemma byte_eqb_refl x : Byte.eqb x x = true.
Proof. now apply Byte.byte_dec_lb. Qed.

Lemma byte_eqb_neq x y : x <> y -> Byte.eqb x y = false.
Proof.
  intros Hne. destruct (Byte.eqb x y) eqn:E; [|reflexivity].
  apply byte_eqb_true in E. contradiction.
Qed.

Definition bindex_of_nth := index_of_nth Byte.eqb byte_eqb_true byte_eqb_refl.
Definition bindex_of_Some := index_of_Some Byte.eqb byte_eqb_true.
Definition bindex_of_not_In := index_of_not_In Byte.eqb byte_eqb_true.

(** ** Configurations *)

Record config := {
  char62 : byte;   (** the character encoding the value 62 *)
  char63 : byte;   (** the character encoding the value 63 *)
  pad : bool       (** whether to emit (and require) [=] padding *)
}.

(** The 62 characters shared by every variant: values 0..61. *)
Definition base_chars : list byte :=
  list_byte_of_string
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".

Definition alphabet (c : config) : list byte :=
  base_chars ++ [char62 c; char63 c].

Definition pad_char : byte := "="%byte.

Definition standard   : config := {| char62 := "+"; char63 := "/"; pad := true  |}.
Definition url        : config := {| char62 := "-"; char63 := "_"; pad := false |}.
Definition url_padded : config := {| char62 := "-"; char63 := "_"; pad := true  |}.

(** ** Well-formed configurations

    A configuration makes sense when its 64 characters are distinct and none of
    them is the padding character. Everything proved about base64 below assumes
    only this, so a user-supplied alphabet gets the whole theory for free. *)

Definition wf (c : config) : Prop :=
  NoDup (alphabet c) /\ ~ In pad_char (alphabet c).

(** [wf] is decidable, which is how the shipped configurations discharge it. *)

Fixpoint nodup_check (l : list byte) : bool :=
  match l with
  | [] => true
  | x :: l => andb (negb (existsb (Byte.eqb x) l)) (nodup_check l)
  end.

Lemma nodup_check_sound l : nodup_check l = true -> NoDup l.
Proof.
  induction l as [|x l IH]; intros H; [constructor|].
  cbn in H. apply Bool.andb_true_iff in H as [Hx Hl].
  constructor; [|now apply IH].
  intros Hin. apply Bool.negb_true_iff in Hx.
  enough (existsb (Byte.eqb x) l = true) by congruence.
  apply existsb_exists. exists x. split; [exact Hin|].
  now apply Byte.byte_dec_lb.
Qed.

Definition wf_check (c : config) : bool :=
  andb (nodup_check (alphabet c))
       (negb (existsb (Byte.eqb pad_char) (alphabet c))).

Lemma wf_check_sound c : wf_check c = true -> wf c.
Proof.
  unfold wf_check, wf. intros H. apply Bool.andb_true_iff in H as [Hnd Hpad].
  split; [now apply nodup_check_sound|].
  apply Bool.negb_true_iff in Hpad. intros Hin.
  enough (existsb (Byte.eqb pad_char) (alphabet c) = true) by congruence.
  apply existsb_exists. exists pad_char. split; [exact Hin|].
  now apply Byte.byte_dec_lb.
Qed.

Lemma standard_wf : wf standard.
Proof. apply wf_check_sound. vm_compute. reflexivity. Qed.

Lemma url_wf : wf url.
Proof. apply wf_check_sound. vm_compute. reflexivity. Qed.

Lemma url_padded_wf : wf url_padded.
Proof. apply wf_check_sound. vm_compute. reflexivity. Qed.

(** ** Sextets and alphabet characters

    Encoding a sextet is a table lookup; decoding a character is the reverse
    lookup. Because the table is duplicate-free and exactly 64 long, the two
    are mutually inverse. *)

Lemma length_alphabet c : length (alphabet c) = 64.
Proof. reflexivity. Qed.

Definition enc_sextet (c : config) (s : sextet) : byte :=
  nth (sextet_to_nat s) (alphabet c) Byte.x00.

Definition dec_byte (c : config) (b : byte) : option sextet :=
  option_map nat_to_sextet (index_of Byte.eqb b (alphabet c)).

Lemma sextet_to_nat_to_sextet n : n < 64 -> sextet_to_nat (nat_to_sextet n) = n.
Proof. intros H. do 64 (destruct n as [|n]; [reflexivity|]). lia. Qed.

Lemma dec_enc c s : wf c -> dec_byte c (enc_sextet c s) = Some s.
Proof.
  intros [Hnd _]. unfold dec_byte, enc_sextet.
  rewrite bindex_of_nth
    by (assumption || (rewrite length_alphabet; apply sextet_to_nat_lt)).
  cbn [option_map]. now rewrite nat_to_sextet_to_nat.
Qed.

Lemma enc_dec c b s : dec_byte c b = Some s -> enc_sextet c s = b.
Proof.
  unfold dec_byte, enc_sextet. intros H.
  destruct (index_of Byte.eqb b (alphabet c)) as [n|] eqn:Hi; cbn in H; [|discriminate].
  injection H as <-.
  apply (bindex_of_Some b (alphabet c) n Byte.x00) in Hi as [Hlt Hnth].
  rewrite length_alphabet in Hlt.
  rewrite sextet_to_nat_to_sextet by exact Hlt. exact Hnth.
Qed.

(** The characters a well-formed configuration emits are in its alphabet, and
    in particular are never the padding character. *)

Lemma enc_sextet_In c s : In (enc_sextet c s) (alphabet c).
Proof.
  unfold enc_sextet. apply nth_In.
  rewrite length_alphabet. apply sextet_to_nat_lt.
Qed.

Lemma enc_sextet_not_pad c s : wf c -> enc_sextet c s <> pad_char.
Proof.
  intros [_ Hpad] Heq. apply Hpad. rewrite <- Heq. apply enc_sextet_In.
Qed.

(** Dually, anything outside the alphabet fails to decode -- the padding
    character above all, which is what lets [decode] treat [=] as a delimiter
    rather than as data. *)

Lemma dec_byte_not_In c b : ~ In b (alphabet c) -> dec_byte c b = None.
Proof.
  intros Hnin. unfold dec_byte.
  rewrite bindex_of_not_In by exact Hnin. reflexivity.
Qed.

Lemma dec_byte_pad c : wf c -> dec_byte c pad_char = None.
Proof. intros [_ Hpad]. now apply dec_byte_not_In. Qed.

Lemma dec_byte_Some_In c b s : dec_byte c b = Some s -> In b (alphabet c).
Proof.
  intros H. apply enc_dec in H as <-. apply enc_sextet_In.
Qed.

(** * Base64 encoding and decoding over byte lists

    This is the core of the library: [encode] and [decode] on [list byte],
    together with the two roundtrip theorems. The bridges to MetaRocq
    bytestrings and to primitive strings are both derived from what is proved
    here, so this is the only place the algorithm is reasoned about.

    The decoder is deliberately strict. It rejects input whose length is not a
    valid base64 length, input containing characters outside the configured
    alphabet, padding in the wrong place, and -- crucially -- a final group
    whose spare low bits are not zero. Strictness is what makes [decode] a
    left *and* right inverse of [encode] rather than merely a left inverse:
    without it, both ["QQ=="] and ["QR=="] would decode to the same byte and
    [encode_decode] below would be false. *)

From Stdlib Require Import Strings.Byte Lists.List.
From Stdlib Require Import Arith.PeanoNat Lia.
From Base64 Require Import Util Sextet Alphabet.
Import ListNotations.

(** ** Encoding *)

Fixpoint encode (c : config) (bs : list byte) : list byte :=
  match bs with
  | [] => []
  | [x] =>
      let '(s, t) := sextets_of_1 x in
      [enc_sextet c s; enc_sextet c t]
        ++ (if pad c then [pad_char; pad_char] else [])
  | [x; y] =>
      let '(s, t, u) := sextets_of_2 x y in
      [enc_sextet c s; enc_sextet c t; enc_sextet c u]
        ++ (if pad c then [pad_char] else [])
  | x :: y :: z :: bs =>
      let '(s, t, u, v) := sextets_of_3 x y z in
      [enc_sextet c s; enc_sextet c t; enc_sextet c u; enc_sextet c v]
        ++ encode c bs
  end.

(** ** Decoding

    One group at a time: four characters give three bytes, and a final group of
    four with one or two trailing [=], or of three or two characters when the
    configuration is unpadded, gives two bytes or one. *)

Definition dec_quad (c : config) (a b d e : byte) : option (list byte) :=
  match dec_byte c a, dec_byte c b, dec_byte c d, dec_byte c e with
  | Some s, Some t, Some u, Some v =>
      let '(x, y, z) := bytes_of_4 s t u v in Some [x; y; z]
  | _, _, _, _ => None
  end.

Definition dec_triple (c : config) (a b d : byte) : option (list byte) :=
  match dec_byte c a, dec_byte c b, dec_byte c d with
  | Some s, Some t, Some u =>
      option_map (fun xy => let '(x, y) := xy in [x; y]) (bytes_of_3 s t u)
  | _, _, _ => None
  end.

Definition dec_pair (c : config) (a b : byte) : option (list byte) :=
  match dec_byte c a, dec_byte c b with
  | Some s, Some t => option_map (fun x => [x]) (bytes_of_2 s t)
  | _, _ => None
  end.

Fixpoint decode (c : config) (l : list byte) : option (list byte) :=
  match l with
  | [] => Some []
  | [a; b] => if pad c then None else dec_pair c a b
  | [a; b; d] => if pad c then None else dec_triple c a b d
  | [a; b; d; e] =>
      if pad c then
        (if Byte.eqb e pad_char then
           (if Byte.eqb d pad_char then dec_pair c a b else dec_triple c a b d)
         else dec_quad c a b d e)
      else dec_quad c a b d e
  | a :: b :: d :: e :: l =>
      match dec_quad c a b d e, decode c l with
      | Some bs, Some bs' => Some (bs ++ bs')
      | _, _ => None
      end
  | _ => None   (** a length of 1 modulo 4 is never valid *)
  end.

(** ** Group-level correspondence

    Six small lemmas relating [encode]'s output on one group to the [dec_*]
    functions. The main theorems are then little more than bookkeeping. *)

Lemma dec_quad_enc c x y z s t u v :
  wf c -> sextets_of_3 x y z = (s, t, u, v) ->
  dec_quad c (enc_sextet c s) (enc_sextet c t) (enc_sextet c u) (enc_sextet c v)
  = Some [x; y; z].
Proof.
  intros Hwf Hs. unfold dec_quad. rewrite !dec_enc by exact Hwf.
  rewrite (bytes_of_4_sextets_of_3 _ _ _ _ _ _ _ Hs). reflexivity.
Qed.

Lemma dec_triple_enc c x y s t u :
  wf c -> sextets_of_2 x y = (s, t, u) ->
  dec_triple c (enc_sextet c s) (enc_sextet c t) (enc_sextet c u) = Some [x; y].
Proof.
  intros Hwf Hs. unfold dec_triple. rewrite !dec_enc by exact Hwf.
  rewrite (bytes_of_3_sextets_of_2 _ _ _ _ _ Hs). reflexivity.
Qed.

Lemma dec_pair_enc c x s t :
  wf c -> sextets_of_1 x = (s, t) ->
  dec_pair c (enc_sextet c s) (enc_sextet c t) = Some [x].
Proof.
  intros Hwf Hs. unfold dec_pair. rewrite !dec_enc by exact Hwf.
  rewrite (bytes_of_2_sextets_of_1 _ _ _ Hs). reflexivity.
Qed.

Lemma dec_quad_inv c a b d e bs :
  dec_quad c a b d e = Some bs ->
  exists x y z, bs = [x; y; z] /\
    forall bs', encode c (x :: y :: z :: bs') = [a; b; d; e] ++ encode c bs'.
Proof.
  unfold dec_quad. intros H.
  destruct (dec_byte c a) as [s|] eqn:Ha; [|discriminate].
  destruct (dec_byte c b) as [t|] eqn:Hb; [|discriminate].
  destruct (dec_byte c d) as [u|] eqn:Hd; [|discriminate].
  destruct (dec_byte c e) as [v|] eqn:He; [|discriminate].
  destruct (bytes_of_4 s t u v) as [[x y] z] eqn:Hb4.
  injection H as <-. exists x, y, z. split; [reflexivity|]. intros bs'.
  cbn [encode]. rewrite (sextets_of_3_bytes_of_4 _ _ _ _ _ _ _ Hb4).
  apply enc_dec in Ha, Hb, Hd, He. now rewrite Ha, Hb, Hd, He.
Qed.

Lemma dec_triple_inv c a b d bs :
  dec_triple c a b d = Some bs ->
  exists x y, bs = [x; y] /\
    encode c [x; y] = [a; b; d] ++ (if pad c then [pad_char] else []).
Proof.
  unfold dec_triple. intros H.
  destruct (dec_byte c a) as [s|] eqn:Ha; [|discriminate].
  destruct (dec_byte c b) as [t|] eqn:Hb; [|discriminate].
  destruct (dec_byte c d) as [u|] eqn:Hd; [|discriminate].
  destruct (bytes_of_3 s t u) as [[x y]|] eqn:Hb3; cbn in H; [|discriminate].
  injection H as <-. exists x, y. split; [reflexivity|].
  cbn [encode]. rewrite (sextets_of_2_bytes_of_3 _ _ _ _ _ Hb3).
  apply enc_dec in Ha, Hb, Hd. now rewrite Ha, Hb, Hd.
Qed.

Lemma dec_pair_inv c a b bs :
  dec_pair c a b = Some bs ->
  exists x, bs = [x] /\
    encode c [x] = [a; b] ++ (if pad c then [pad_char; pad_char] else []).
Proof.
  unfold dec_pair. intros H.
  destruct (dec_byte c a) as [s|] eqn:Ha; [|discriminate].
  destruct (dec_byte c b) as [t|] eqn:Hb; [|discriminate].
  destruct (bytes_of_2 s t) as [x|] eqn:Hb2; cbn in H; [|discriminate].
  injection H as <-. exists x. split; [reflexivity|].
  cbn [encode]. rewrite (sextets_of_1_bytes_of_2 _ _ _ Hb2).
  apply enc_dec in Ha, Hb. now rewrite Ha, Hb.
Qed.

(** ** Unfolding [decode]

    [decode]'s match overlaps a final group of exactly four characters with the
    general case, so these equations are stated once rather than relying on
    [cbn] to pick the right branch in each proof below. *)

Lemma decode_nil c : decode c [] = Some [].
Proof. reflexivity. Qed.

Lemma decode_single c a : decode c [a] = None.
Proof. reflexivity. Qed.

Lemma decode_pair_eq c a b :
  decode c [a; b] = if pad c then None else dec_pair c a b.
Proof. reflexivity. Qed.

Lemma decode_triple_eq c a b d :
  decode c [a; b; d] = if pad c then None else dec_triple c a b d.
Proof. reflexivity. Qed.

Lemma decode_quad_eq c a b d e :
  decode c [a; b; d; e] =
  if pad c then
    (if Byte.eqb e pad_char then
       (if Byte.eqb d pad_char then dec_pair c a b else dec_triple c a b d)
     else dec_quad c a b d e)
  else dec_quad c a b d e.
Proof. reflexivity. Qed.

Lemma decode_cons4 c a b d e l :
  l <> [] ->
  decode c (a :: b :: d :: e :: l) =
  match dec_quad c a b d e, decode c l with
  | Some bs, Some bs' => Some (bs ++ bs')
  | _, _ => None
  end.
Proof. destruct l as [|g l]; [congruence|reflexivity]. Qed.

Lemma encode_nil c : encode c [] = [].
Proof. reflexivity. Qed.

Lemma encode_nil_inv c bs : encode c bs = [] -> bs = [].
Proof.
  destruct bs as [|x [|y [|z bs]]]; intros H; try reflexivity; cbn [encode] in H.
  - destruct (sextets_of_1 x). discriminate.
  - destruct (sextets_of_2 x y) as [[s t] u]. discriminate.
  - destruct (sextets_of_3 x y z) as [[[s t] u] v]. discriminate.
Qed.

(** ** The roundtrip theorems *)

(** Everything [encode] produces is accepted, and decodes back unchanged. *)
Theorem decode_encode c bs : wf c -> decode c (encode c bs) = Some bs.
Proof.
  intros Hwf. induction bs as [|x|x y|x y z bs IH] using list_ind3.
  - reflexivity.
  - cbn [encode]. destruct (sextets_of_1 x) as [s t] eqn:Hs.
    destruct (pad c) eqn:Hp; cbn [app].
    + rewrite decode_quad_eq, Hp, byte_eqb_refl.
      now rewrite (dec_pair_enc c x s t Hwf Hs).
    + rewrite decode_pair_eq, Hp.
      now rewrite (dec_pair_enc c x s t Hwf Hs).
  - cbn [encode]. destruct (sextets_of_2 x y) as [[s t] u] eqn:Hs.
    destruct (pad c) eqn:Hp; cbn [app].
    + rewrite decode_quad_eq, Hp, byte_eqb_refl.
      rewrite (byte_eqb_neq _ _ (enc_sextet_not_pad c u Hwf)).
      now rewrite (dec_triple_enc c x y s t u Hwf Hs).
    + rewrite decode_triple_eq, Hp.
      now rewrite (dec_triple_enc c x y s t u Hwf Hs).
  - cbn [encode]. destruct (sextets_of_3 x y z) as [[[s t] u] v] eqn:Hs.
    destruct bs as [|w bs'].
    + cbn [app encode]. rewrite decode_quad_eq. destruct (pad c) eqn:Hp.
      * rewrite (byte_eqb_neq _ _ (enc_sextet_not_pad c v Hwf)).
        now rewrite (dec_quad_enc c x y z s t u v Hwf Hs).
      * now rewrite (dec_quad_enc c x y z s t u v Hwf Hs).
    + destruct (encode c (w :: bs')) as [|g rest] eqn:He.
      * exfalso. apply encode_nil_inv in He. discriminate.
      * cbn [app]. rewrite decode_cons4 by discriminate.
        rewrite (dec_quad_enc c x y z s t u v Hwf Hs), IH. reflexivity.
Qed.

(** Conversely, anything [decode] accepts is exactly what [encode] would have
    produced. This is the direction that depends on the decoder being strict. *)
Theorem encode_decode c l bs : wf c -> decode c l = Some bs -> encode c bs = l.
Proof.
  intros Hwf. revert bs.
  induction l as [|a|a b|a b d|a b d e l IH] using list_ind4; intros bs H.
  - rewrite decode_nil in H. injection H as <-. reflexivity.
  - rewrite decode_single in H. discriminate.
  - rewrite decode_pair_eq in H. destruct (pad c) eqn:Hp; [discriminate|].
    apply dec_pair_inv in H as [x [-> Hx]]. rewrite Hx, Hp. reflexivity.
  - rewrite decode_triple_eq in H. destruct (pad c) eqn:Hp; [discriminate|].
    apply dec_triple_inv in H as [x [y [-> Hx]]]. rewrite Hx, Hp. reflexivity.
  - destruct l as [|g l'].
    + rewrite decode_quad_eq in H. destruct (pad c) eqn:Hp.
      * destruct (Byte.eqb e pad_char) eqn:He.
        -- apply byte_eqb_true in He as ->.
           destruct (Byte.eqb d pad_char) eqn:Hd.
           ++ apply byte_eqb_true in Hd as ->.
              apply dec_pair_inv in H as [x [-> Hx]]. rewrite Hx, Hp. reflexivity.
           ++ apply dec_triple_inv in H as [x [y [-> Hx]]]. rewrite Hx, Hp. reflexivity.
        -- apply dec_quad_inv in H as [x [y [z [-> Hx]]]].
           rewrite (Hx []). reflexivity.
      * apply dec_quad_inv in H as [x [y [z [-> Hx]]]].
        rewrite (Hx []). reflexivity.
    + rewrite decode_cons4 in H by discriminate.
      destruct (dec_quad c a b d e) as [bs1|] eqn:Hq; [|discriminate].
      destruct (decode c (g :: l')) as [bs2|] eqn:Hr; [|discriminate].
      injection H as <-.
      (* The [destruct] above rewrote the recursive call inside [IH] as well,
         so discharge [IH]'s premise rather than citing [Hr] directly. *)
      assert (Hbs2 : encode c bs2 = g :: l') by (apply IH; (reflexivity || exact Hr)).
      apply dec_quad_inv in Hq as [x [y [z [-> Hx]]]].
      cbn [app]. rewrite (Hx bs2), Hbs2. reflexivity.
Qed.

(** ** Consequences

    Both maps are injective, and [decode] determines its input. *)

Corollary encode_inj c bs1 bs2 : wf c -> encode c bs1 = encode c bs2 -> bs1 = bs2.
Proof.
  intros Hwf Heq.
  assert (Some bs1 = Some bs2) as H by
    (rewrite <- (decode_encode c bs1 Hwf), <- (decode_encode c bs2 Hwf), Heq;
     reflexivity).
  now injection H as <-.
Qed.

Corollary decode_inj c l1 l2 bs :
  wf c -> decode c l1 = Some bs -> decode c l2 = Some bs -> l1 = l2.
Proof.
  intros Hwf H1 H2.
  rewrite <- (encode_decode c l1 bs Hwf H1), <- (encode_decode c l2 bs Hwf H2).
  reflexivity.
Qed.

Corollary decode_encode_iff c l bs :
  wf c -> decode c l = Some bs <-> encode c bs = l.
Proof.
  intros Hwf. split.
  - now apply encode_decode.
  - intros <-. now apply decode_encode.
Qed.

(** ** Length of the output

    Three bytes become four characters. A padded configuration rounds the input
    length up to a multiple of three; an unpadded one emits only the characters
    the remaining bits need. *)

Theorem encode_length c bs :
  length (encode c bs) =
  if pad c then 4 * ((length bs + 2) / 3)
  else 4 * (length bs / 3) + match length bs mod 3 with
                             | 0 => 0
                             | 1 => 2
                             | _ => 3
                             end.
Proof.
  induction bs as [|x|x y|x y z bs IH] using list_ind3.
  - destruct (pad c); reflexivity.
  - cbn [encode]. destruct (sextets_of_1 x) as [s t].
    destruct (pad c); reflexivity.
  - cbn [encode]. destruct (sextets_of_2 x y) as [[s t] u].
    destruct (pad c); reflexivity.
  - cbn [encode]. destruct (sextets_of_3 x y z) as [[[s t] u] v].
    rewrite length_app. cbn [length]. rewrite IH.
    replace (S (S (S (length bs))) + 2) with ((length bs + 2) + 1 * 3) by lia.
    replace (S (S (S (length bs)))) with (length bs + 1 * 3) by lia.
    rewrite !Nat.div_add by lia. rewrite !Nat.Div0.mod_add.
    destruct (pad c); lia.
Qed.

(** A crude bound, but one a caller can actually discharge: it is what the
    primitive-string bridge uses to meet the [max_length] side condition. *)
Corollary encode_length_le c bs : length (encode c bs) <= 2 * length bs + 4.
Proof.
  rewrite encode_length.
  pose proof (Nat.Div0.mul_div_le (length bs + 2) 3).
  pose proof (Nat.Div0.mul_div_le (length bs) 3).
  pose proof (Nat.mod_upper_bound (length bs) 3 ltac:(lia)).
  destruct (pad c); [lia|].
  destruct (length bs mod 3) as [|[|m]]; lia.
Qed.

(** ** Which characters appear in the output *)

Theorem encode_charset c bs :
  Forall (fun b => In b (alphabet c) \/ b = pad_char) (encode c bs).
Proof.
  assert (Henc : forall s, In (enc_sextet c s) (alphabet c) \/ enc_sextet c s = pad_char)
    by (intros s; left; apply enc_sextet_In).
  induction bs as [|x|x y|x y z bs IH] using list_ind3.
  - constructor.
  - cbn [encode]. destruct (sextets_of_1 x) as [s t].
    destruct (pad c); cbn [app];
      repeat (apply Forall_cons; [solve [apply Henc | right; reflexivity]|]);
      apply Forall_nil.
  - cbn [encode]. destruct (sextets_of_2 x y) as [[s t] u].
    destruct (pad c); cbn [app];
      repeat (apply Forall_cons; [solve [apply Henc | right; reflexivity]|]);
      apply Forall_nil.
  - cbn [encode]. destruct (sextets_of_3 x y z) as [[[s t] u] v]. cbn [app].
    repeat (apply Forall_cons; [apply Henc|]). exact IH.
Qed.

(** ** Compositionality

    Encoding is only compositional at group boundaries: a padded final group
    would otherwise end up in the middle of the output. *)

Theorem encode_app c bs1 bs2 :
  length bs1 mod 3 = 0 -> encode c (bs1 ++ bs2) = encode c bs1 ++ encode c bs2.
Proof.
  revert bs2. induction bs1 as [|x|x y|x y z bs1 IH] using list_ind3;
    intros bs2 Hlen.
  - reflexivity.
  - discriminate.
  - discriminate.
  - cbn [length] in Hlen.
    replace (S (S (S (length bs1)))) with (length bs1 + 1 * 3) in Hlen by lia.
    rewrite Nat.Div0.mod_add in Hlen.
    cbn [app encode]. destruct (sextets_of_3 x y z) as [[[s t] u] v].
    rewrite IH by exact Hlen. now rewrite ?app_assoc.
Qed.

(** The output is never shorter than the input, which is what lets the
    primitive-string bridge bound a decoded length by its input length. *)
Corollary encode_length_ge c bs : length bs <= length (encode c bs).
Proof.
  rewrite encode_length.
  pose proof (Nat.mul_succ_div_gt (length bs + 2) 3 ltac:(lia)).
  pose proof (Nat.div_mod_eq (length bs) 3).
  pose proof (Nat.mod_upper_bound (length bs) 3 ltac:(lia)).
  destruct (pad c); [lia|].
  destruct (length bs mod 3) as [|[|m]]; lia.
Qed.

Corollary decode_length_le c l bs :
  wf c -> decode c l = Some bs -> length bs <= length l.
Proof.
  intros Hwf H. apply (encode_decode c l bs Hwf) in H as <-.
  apply encode_length_ge.
Qed.

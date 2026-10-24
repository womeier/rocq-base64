(** * Base64 over byte-convertible strings

    [fits] describes the byte lists a representation can hold. Conversion back
    to bytes is an inverse only for lists that fit; existing strings always
    fit, and shorter lists fit too. This accommodates bounded primitive strings
    without imposing bounds on the other representations. *)

From Stdlib Require Import Strings.Byte Lists.List Arith.PeanoNat.
From Base64 Require Import Alphabet Base64.

Class ByteString (S : Type) := {
  to_bytes : S -> list byte;
  of_bytes : list byte -> S;
  fits : list byte -> Prop;
  of_to_bytes : forall s, of_bytes (to_bytes s) = s;
  to_of_bytes : forall bs, fits bs -> to_bytes (of_bytes bs) = bs;
  fits_to_bytes : forall s, fits (to_bytes s);
  fits_shorter : forall xs ys, length xs <= length ys -> fits ys -> fits xs
}.

Arguments to_bytes {S} {_} s.
Arguments of_bytes {S} {_} bs.
Arguments fits {S} {_} bs.

#[export] Instance byte_list_bytestring : ByteString (list byte) := {
  to_bytes bs := bs;
  of_bytes bs := bs;
  fits _ := True;
  of_to_bytes _ := eq_refl;
  to_of_bytes _ _ := eq_refl;
  fits_to_bytes _ := I;
  fits_shorter _ _ _ _ := I
}.

Section ByteString.
Context {S : Type} `{ByteString S}.

Definition encode (c : config) (s : S) : S :=
  of_bytes (Base64.encode c (to_bytes s)).

Definition decode (c : config) (s : S) : option S :=
  option_map of_bytes (Base64.decode c (to_bytes s)).

Local Definition append (s t : S) : S := of_bytes (to_bytes s ++ to_bytes t).

Lemma encode_of_bytes c bs :
  fits bs -> encode c (of_bytes bs) = of_bytes (Base64.encode c bs).
Proof. intros Hfits. unfold encode. now rewrite to_of_bytes. Qed.

Lemma decode_of_bytes c bs :
  fits bs -> decode c (of_bytes bs) = option_map of_bytes (Base64.decode c bs).
Proof. intros Hfits. unfold decode. now rewrite to_of_bytes. Qed.

Lemma to_bytes_encode c s :
  fits (Base64.encode c (to_bytes s)) ->
  to_bytes (encode c s) = Base64.encode c (to_bytes s).
Proof. apply to_of_bytes. Qed.

Lemma decode_fits c s bs :
  wf_config c -> Base64.decode c (to_bytes s) = Some bs -> fits bs.
Proof.
  intros Hwf Hd. eapply (fits_shorter bs (to_bytes s)); [|apply fits_to_bytes].
  now apply (Base64.decode_length_le c _ bs).
Qed.

Lemma to_bytes_decode c s :
  wf_config c -> option_map to_bytes (decode c s) = Base64.decode c (to_bytes s).
Proof.
  intros Hwf. unfold decode.
  destruct (Base64.decode c (to_bytes s)) as [bs|] eqn:Hd; cbn; [|reflexivity].
  rewrite to_of_bytes; [reflexivity|now apply (decode_fits c s)].
Qed.

Theorem decode_encode c s :
  wf_config c -> fits (Base64.encode c (to_bytes s)) ->
  decode c (encode c s) = Some s.
Proof.
  intros Hwf Hfits. unfold decode. rewrite to_bytes_encode by exact Hfits.
  rewrite Base64.decode_encode by exact Hwf. cbn. now rewrite of_to_bytes.
Qed.

Theorem encode_decode c s t :
  wf_config c -> decode c s = Some t -> encode c t = s.
Proof.
  intros Hwf Hd. unfold decode in Hd.
  destruct (Base64.decode c (to_bytes s)) as [bs|] eqn:Hbs;
    cbn in Hd; [|discriminate].
  injection Hd as <-. unfold encode.
  rewrite to_of_bytes by (now apply (decode_fits c s)).
  rewrite (Base64.encode_decode c _ bs Hwf Hbs). apply of_to_bytes.
Qed.

Corollary decode_encode_iff c s t :
  wf_config c -> fits (Base64.encode c (to_bytes t)) ->
  decode c s = Some t <-> encode c t = s.
Proof.
  intros Hwf Hfits. split; [now apply encode_decode|].
  intros <-. now apply decode_encode.
Qed.

Corollary encode_inj c s t :
  wf_config c ->
  fits (Base64.encode c (to_bytes s)) ->
  fits (Base64.encode c (to_bytes t)) ->
  encode c s = encode c t -> s = t.
Proof.
  intros Hwf Hs Ht Heq.
  assert (Some s = Some t) as Hst by
    (rewrite <- (decode_encode c s Hwf Hs), <- (decode_encode c t Hwf Ht), Heq;
     reflexivity).
  now injection Hst as <-.
Qed.

Lemma encode_length c s :
  fits (Base64.encode c (to_bytes s)) ->
  length (to_bytes (encode c s)) =
  if pad c then 4 * ((length (to_bytes s) + 2) / 3)
  else 4 * (length (to_bytes s) / 3) +
    match length (to_bytes s) mod 3 with 0 => 0 | 1 => 2 | _ => 3 end.
Proof.
  intros Hfits. rewrite to_bytes_encode by exact Hfits. apply Base64.encode_length.
Qed.

(** Concatenation and the two encoded pieces must fit so that converting them
    preserves their bytes. The final encoded concatenation need not fit: both
    sides construct it through the same [of_bytes]. *)
Theorem encode_app c s t :
  length (to_bytes s) mod 3 = 0 ->
  fits (to_bytes s ++ to_bytes t) ->
  fits (Base64.encode c (to_bytes s)) ->
  fits (Base64.encode c (to_bytes t)) ->
  encode c (append s t) = append (encode c s) (encode c t).
Proof.
  intros Hlen Hst Hs Ht. unfold append, encode.
  rewrite !to_of_bytes by assumption.
  now rewrite Base64.encode_app.
Qed.

End ByteString.

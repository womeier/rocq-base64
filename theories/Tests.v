(** * Test vectors

    The vectors from RFC 4648 section 10, checked by computation in all four
    representations and for all four shipped configurations, plus negative
    tests that pin down what the strict decoder rejects.

    These are regression tests: if the bit layout in [Sextet] or the alphabet
    table in [Alphabet] is ever wrong, the roundtrip theorems still hold (they
    only say the two directions agree) but these checks fail. *)

From Stdlib Require Import Strings.Byte Strings.String Lists.List.
From Stdlib Require Import Strings.PrimString Strings.PrimStringAxioms.
From Stdlib Require Import ZArith Numbers.Cyclic.Int63.Uint63.
From Base64 Require Import All.
Import ListNotations.

(** ** Byte lists *)

Definition b (x : String.string) : list byte := list_byte_of_string x.

Example encode_empty  : encode standard (b "")       = b "".         Proof. reflexivity. Qed.
Example encode_f      : encode standard (b "f")      = b "Zg==".     Proof. reflexivity. Qed.
Example encode_fo     : encode standard (b "fo")     = b "Zm8=".     Proof. reflexivity. Qed.
Example encode_foo    : encode standard (b "foo")    = b "Zm9v".     Proof. reflexivity. Qed.
Example encode_foob   : encode standard (b "foob")   = b "Zm9vYg==". Proof. reflexivity. Qed.
Example encode_fooba  : encode standard (b "fooba")  = b "Zm9vYmE=". Proof. reflexivity. Qed.
Example encode_foobar : encode standard (b "foobar") = b "Zm9vYmFy". Proof. reflexivity. Qed.

Example decode_empty  : decode standard (b "")         = Some (b "").       Proof. reflexivity. Qed.
Example decode_f      : decode standard (b "Zg==")     = Some (b "f").      Proof. reflexivity. Qed.
Example decode_fo     : decode standard (b "Zm8=")     = Some (b "fo").     Proof. reflexivity. Qed.
Example decode_foo    : decode standard (b "Zm9v")     = Some (b "foo").    Proof. reflexivity. Qed.
Example decode_foob   : decode standard (b "Zm9vYg==") = Some (b "foob").   Proof. reflexivity. Qed.
Example decode_fooba  : decode standard (b "Zm9vYmE=") = Some (b "fooba").  Proof. reflexivity. Qed.
Example decode_foobar : decode standard (b "Zm9vYmFy") = Some (b "foobar"). Proof. reflexivity. Qed.

(** A longer vector, and one exercising all three high bits of the alphabet. *)
Example encode_sentence :
  encode standard (b "any carnal pleasure")
  = b "YW55IGNhcm5hbCBwbGVhc3VyZQ==".
Proof. reflexivity. Qed.

(** Bytes 251..255 land on the top of the alphabet, including [char_62] and
    [char_63] -- the only two characters the configuration varies. *)
Example encode_high_standard :
  encode standard [Byte.xfb; Byte.xff; Byte.xbf] = b "+/+/".
Proof. reflexivity. Qed.

Example encode_high_url :
  encode url [Byte.xfb; Byte.xff; Byte.xbf] = b "-_-_".
Proof. reflexivity. Qed.

(** ** The url alphabet, which is unpadded *)

Example encode_url_f      : encode url (b "f")      = b "Zg".       Proof. reflexivity. Qed.
Example encode_url_fo     : encode url (b "fo")     = b "Zm8".      Proof. reflexivity. Qed.
Example encode_url_foo    : encode url (b "foo")    = b "Zm9v".     Proof. reflexivity. Qed.
Example encode_url_foob   : encode url (b "foob")   = b "Zm9vYg".   Proof. reflexivity. Qed.
Example decode_url_foob   : decode url (b "Zm9vYg") = Some (b "foob"). Proof. reflexivity. Qed.

(** ** The standard alphabet, unpadded

    The fourth configuration: section 4's characters with the padding dropped.
    It agrees with [standard] exactly on the inputs whose length is a multiple
    of three, where no padding would be emitted anyway. *)

Example encode_sunpad_f      : encode standard_unpadded (b "f")      = b "Zg".
Proof. reflexivity. Qed.
Example encode_sunpad_fo     : encode standard_unpadded (b "fo")     = b "Zm8".
Proof. reflexivity. Qed.
Example encode_sunpad_foo    : encode standard_unpadded (b "foo")    = b "Zm9v".
Proof. reflexivity. Qed.
Example decode_sunpad_f      : decode standard_unpadded (b "Zg")     = Some (b "f").
Proof. reflexivity. Qed.

(** It keeps [+] and [/], which is what distinguishes it from [url]. *)
Example encode_sunpad_high :
  encode standard_unpadded [Byte.xfb; Byte.xff; Byte.xbf] = b "+/+/".
Proof. reflexivity. Qed.

(** Being unpadded, it rejects the padding [standard] requires -- and vice
    versa. These two are the only reason the config exists. *)
Example reject_sunpad_padded : decode standard_unpadded (b "Zg==") = None.
Proof. reflexivity. Qed.
Example reject_standard_unpadded : decode standard (b "Zg") = None.
Proof. reflexivity. Qed.

(** ** What the strict decoder rejects *)

(** A length of one modulo four is never valid. *)
Example reject_length : decode standard (b "Zg==Z") = None. Proof. reflexivity. Qed.

(** Characters outside the alphabet. *)
Example reject_stray : decode standard (b "Zg!=") = None. Proof. reflexivity. Qed.

(** Padding in the middle of the input. *)
Example reject_mid_pad : decode standard (b "Zg==Zg==") = None. Proof. reflexivity. Qed.

(** Padding where a character belongs. *)
Example reject_misplaced_pad : decode standard (b "Z===") = None. Proof. reflexivity. Qed.

(** Non-canonical trailing bits: ["QQ=="] is the canonical encoding of one
    byte, and ["QR=="] denotes the same byte with spare bits set. A lenient
    decoder accepts both, which would make [encode_decode] false. *)
Example accept_canonical : decode standard (b "QQ==") = Some [Byte.x41].
Proof. reflexivity. Qed.
Example reject_noncanonical : decode standard (b "QR==") = None.
Proof. reflexivity. Qed.

(** A padded configuration requires the padding, and an unpadded one rejects
    it -- [=] is not in either alphabet. *)
Example reject_missing_pad : decode standard (b "Zg") = None. Proof. reflexivity. Qed.
Example reject_short_pad   : decode standard (b "Zg=") = None. Proof. reflexivity. Qed.
Example reject_url_padded  : decode url (b "Zg==")     = None. Proof. reflexivity. Qed.

(** ** Standard library strings *)

(* The uniform API has no representation-specific argument scope, so annotate
   input literals explicitly. The open scope covers the expected outputs. *)
Open Scope string_scope.

Example encode_str_foobar : encode standard "foobar"%string = "Zm9vYmFy".
Proof. reflexivity. Qed.
Example encode_str_foob : encode standard "foob"%string = "Zm9vYg==".
Proof. reflexivity. Qed.
Example encode_str_url_foob : encode url "foob"%string = "Zm9vYg".
Proof. reflexivity. Qed.
Example decode_str_foob : decode standard "Zm9vYg=="%string = Some "foob".
Proof. reflexivity. Qed.
Example decode_str_reject : decode standard "QR=="%string = None.
Proof. reflexivity. Qed.

(** ** Primitive strings *)

Open Scope pstring_scope.

Example encode_ps_foobar : encode standard "foobar"%pstring = "Zm9vYmFy".
Proof. vm_compute. reflexivity. Qed.
Example encode_ps_foob : encode standard "foob"%pstring = "Zm9vYg==".
Proof. vm_compute. reflexivity. Qed.
Example encode_ps_url_foob : encode url "foob"%pstring = "Zm9vYg".
Proof. vm_compute. reflexivity. Qed.
Example decode_ps_foob : decode standard "Zm9vYg=="%pstring = Some "foob".
Proof. vm_compute. reflexivity. Qed.
Example decode_ps_reject : decode standard "QR=="%pstring = None.
Proof. vm_compute. reflexivity. Qed.

(** ** Polymorphic callers and shared correctness proofs *)

Definition roundtrip {S : Type} `{ByteString S} (c : config) (s : S) : option S :=
  decode c (encode c s).

Example roundtrip_bytes c s : wf_config c -> roundtrip c s = Some (s : list byte).
Proof.
  intros Hwf. exact (@ByteString.decode_encode (list byte) byte_list_bytestring c s Hwf I).
Qed.

Example roundtrip_str c s : wf_config c -> roundtrip c s = Some (s : String.string).
Proof.
  intros Hwf. exact (@ByteString.decode_encode String.string string_bytestring c s Hwf I).
Qed.

Example roundtrip_ps_input_bound c (s : PrimString.string) :
  wf_config c ->
  (2 * Uint63.to_Z (PrimString.length s) + 4 <= Uint63.to_Z PrimString.max_length)%Z ->
  roundtrip c s = Some s.
Proof.
  intros Hwf Hlen. exact (ByteString.decode_encode c s Hwf (InstancePrimString.encode_fits c s Hlen)).
Qed.

Example primitive_fits bs :
  fits (S := PrimString.string) bs <->
  (Z.of_nat (List.length bs) <= Uint63.to_Z PrimString.max_length)%Z.
Proof. reflexivity. Qed.

Example stdlib_always_fits bs : fits (S := String.string) bs.
Proof. exact I. Qed.

Example append_ps_foobar :
  encode standard (ByteString.append "foo"%pstring "bar"%pstring) =
  ByteString.append (encode standard "foo"%pstring) (encode standard "bar"%pstring).
Proof. vm_compute. reflexivity. Qed.

(** ** [ByteString.append] agrees with each representation's own *)

(** For byte lists [ByteString.append] is plain [++], and for standard library
    strings it is [String.append]. This is what ties [encode_app] above to the
    concatenation a caller already uses. *)
(* [string_scope] is open above, so spell out that this [++] is the list one. *)
Example append_bytes (s t : list byte) : ByteString.append s t = (s ++ t)%list.
Proof. reflexivity. Qed.

Example append_str_foobar :
  encode standard (ByteString.append "foo"%string "bar"%string) =
  String.append (encode standard "foo"%string) (encode standard "bar"%string).
Proof. reflexivity. Qed.

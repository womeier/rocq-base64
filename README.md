# rocq-base64

[![Nix CI][nix-action-shield]][nix-action-link]
[![MIT License][license-shield]][license-link]

[nix-action-shield]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml/badge.svg?branch=main
[nix-action-link]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml
[license-shield]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: LICENSE

Base64 encoding and **strict** decoding in Rocq, following
[RFC 4648](https://www.rfc-editor.org/rfc/rfc4648), proved correct in both
directions:

```coq
Theorem decode_encode c bs : wf c -> decode c (encode c bs) = Some bs.
Theorem encode_decode c l bs : wf c -> decode c l = Some bs -> encode c bs = l.
```

The core theory is over `list Byte.byte`. On top of it sit two bridges — to
MetaRocq's bytestrings and to Rocq's primitive strings — each with the rewrite
lemmas that push conversions out of the way so goals about either
representation normalize back to the byte-list theory.

- Rocq 9.1 (the version MetaRocq 1.5.1 is packaged for, and the version
  CertiRocq pins)
- Depends only on `rocq-stdlib` and `rocq-metarocq-utils`
- No axioms beyond Rocq's own primitive-string axioms, and those only on the
  primitive-string path — `Print Assumptions decode_encode` reports *Closed
  under the global context*

## Install

```shell
git clone https://github.com/womeier/rocq-base64.git
cd rocq-base64
nix-shell          # or: opam install . --deps-only
make
```

## Usage

```coq
From base64 Require Import All.
From Stdlib Require Import Strings.String.   (* for list_byte_of_string *)

(* bytes *)
Compute encode standard (list_byte_of_string "any carnal pleasure").
     (* = list_byte_of_string "YW55IGNhcm5hbCBwbGVhc3VyZQ==" *)
Compute decode url (list_byte_of_string "Zm9vYg").
     (* = Some (list_byte_of_string "foob") *)

(* MetaRocq bytestrings *)
Compute encode_bs standard (BS.parse (list_byte_of_string "foobar")).

(* primitive strings.  `All` only `Require`s `PrimString`, so that it does not
   shadow `String.string`; import it yourself to get the `"..."` literals. *)
From Stdlib Require Import Strings.PrimString.
Compute encode_ps standard "foobar".   (* = "Zm9vYmFy"%pstring *)
Compute decode_ps url "Zm9vYg".        (* = Some "foob"%pstring *)
```

Every theorem is stated for an arbitrary `c : config` under the hypothesis
`wf c`, so a custom alphabet gets the full theory for free:

```coq
Record config := { char62 : byte; char63 : byte; pad : bool }.
Definition wf (c : config) : Prop := NoDup (alphabet c) /\ ~ In pad_char (alphabet c).
```

| Config       | 62 | 63 | Padded | RFC 4648 |
|--------------|----|----|--------|----------|
| `standard`   | `+` | `/` | yes | §4, "base64" |
| `url`        | `-` | `_` | no  | §5, "base64url" (JWT style) |
| `url_padded` | `-` | `_` | yes | §5 with padding |

`standard_wf`, `url_wf` and `url_padded_wf` discharge `wf` by computation.

## What "strict" means

`decode` returns `None` — it does not round down, skip, or accept — for every
input that is not the unique canonical encoding of some byte string:

| Input | Why rejected |
|---|---|
| `"Zg==Z"` | length ≡ 1 mod 4 |
| `"Zg!="` | character outside the alphabet |
| `"Zg==Zg=="` | padding before the final quad |
| `"Z==="` | too little data before the padding |
| `"QR=="` | non-zero trailing bits (`"QQ=="` is the canonical form) |
| `"Zg"`, `"Zg="` | missing or short padding, under a padded config |
| `"Zg=="` under `url` | padding present, under an unpadded config |

This is what buys the second roundtrip direction: `encode_decode` says every
accepted input is re-encoded to itself, so `decode` has no malleability in the
sense of [eprint 2022/361](https://eprint.iacr.org/2022/361.pdf).

## Modules

| Module | Contents |
|---|---|
| `Util` | `index_of` and the `list_ind3`/`list_ind4` induction principles |
| `Sextet` | the 6-bit word, and the 3↔4 byte/sextet repacking with its six inverse lemmas |
| `Alphabet` | `config`, `wf`, the shipped alphabets, `enc_sextet`/`dec_byte` |
| `Base64` | `encode`, `decode`, both roundtrip theorems, `encode_length`, `encode_charset`, `encode_app` |
| `MetaRocqString` | `encode_bs`/`decode_bs` over `MetaRocq.Utils.bytestring.String.t` |
| `PrimStrings` | `encode_ps`/`decode_ps` over `PrimString.string` |
| `Equiv` | bytestring ↔ primitive string, and the `base64` rewrite database |
| `Tests` | RFC 4648 §10 vectors and the strictness cases above, checked by `make` |
| `All` | re-exports everything but `Tests` |

### Rewriting

`Equiv` exports `base64_simpl`, which is `autorewrite with base64` plus a
reduction of `option_map`. The database holds the unfolding equations
(`encode_bs_eq`, `decode_ps_eq`, …), the conversion-elimination lemmas
(`print_parse`, `parse_print`, `pstring_of_bytes_of_pstring`,
`pstring_of_bs_of_pstring`, …) and the commutation lemmas (`print_encode_bs`,
`encode_bs_parse`, `decode_bs_of_pstring`, …). Together they take a goal stated
over bytestrings or primitive strings down to one over `list byte`, where
`decode_encode` and `encode_decode` apply:

```coq
Goal forall c s, wf c -> decode_bs c (encode_bs c s) = Some s.
Proof.
  intros c s Hwf. base64_simpl.
  rewrite decode_encode by exact Hwf. base64_simpl. reflexivity.
Qed.
```

On the primitive-string side the same script works, with the `max_length`
bound as the only remaining obligation:

```coq
Goal forall c s,
  wf c ->
  (Z.of_nat (length (encode c (bytes_of_pstring s))) <= Uint63.to_Z PrimString.max_length)%Z ->
  decode_ps c (encode_ps c s) = Some s.
Proof.
  intros c s Hwf Hlen. base64_simpl.
  rewrite bytes_of_pstring_of_bytes by exact Hlen.
  rewrite decode_encode by exact Hwf. base64_simpl. reflexivity.
Qed.
```

(Both of these are already proved, as `decode_bs_encode_bs` and
`decode_ps_encode_ps`; they are shown here as the shape a user's own proof
takes.)

### Primitive strings and `max_length`

The two directions are not symmetric, and the asymmetry is real rather than a
proof artifact. *Consuming* a primitive string needs no side condition, because
an existing `pstring` is already short enough:

```coq
Theorem encode_ps_decode_ps c s t : wf c -> decode_ps c s = Some t -> encode_ps c t = s.
```

*Producing* one can overflow `PrimString.max_length`, so `decode_ps_encode_ps`
carries a length bound. `decode_ps_encode_ps'` restates it in the dischargeable
form `2 * length s + 4 <= max_length`.

## Differential test

`make difftest` extracts `encode`/`decode` to OCaml and compares them against
the Rust [`base64`](https://github.com/marshallpierce/rust-base64) crate on
~1.5M cases, all of which currently agree.

Rust's standard library has no base64; that crate is the de-facto
implementation, and it is the right oracle here because its decoder is strict
in exactly the same places ours is — it rejects non-canonical trailing bits by
default, `STANDARD` requires canonical padding, and `URL_SAFE_NO_PAD` requires
none. (Python's `base64.b64decode(..., validate=True)` accepts `"QR=="`, so it
would report false mismatches.)

The corpus is not invented: each family is ported from the crate's own test
suite — the RFC vectors, the exhaustive 64² and 64³ final-quad scans, the
eprint 2022/361 malleability table, the padding-mode and trailing-byte
families — plus seeded random roundtrips and decoder fuzzing. The crate's suite
cannot be run against us directly, as it is written against its internal
`Engine` trait (`internal_encode`, `decode_slice_unchecked`, `DecodeEstimate`),
i.e. against buffer-level details a whole-string `encode`/`decode` does not
have; so the inputs are reused and both implementations are asked for their
answers, which compares behaviour on every case instead of against a
hard-coded expectation.

`make difftest` needs `ocaml`, `cargo` and `rustc` — `nix-shell` provides them
— and it fetches one crate, so it is not part of CI, which has no network.
`tests/reference/Cargo.lock` pins the exact version.

## Limitations

- `dec_byte` is a linear scan of a 64-element table, and the primitive-string
  path converts through `list byte`. Fine for moderate inputs; a
  `PrimInt63`-arithmetic fast path proved equal to the generic one is the
  obvious follow-up for large payloads.
- No bridge to stdlib `String.string` (a list of `ascii`). It is about ten
  lines via `list_byte_of_string`/`string_of_list_byte` if wanted.
- No streaming interface; `encode_app` is the only compositionality lemma.

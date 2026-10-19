# rocq-base64

[![Nix CI][nix-action-shield]][nix-action-link]
[![MIT License][license-shield]][license-link]

[nix-action-shield]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml/badge.svg?branch=main
[nix-action-link]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml
[license-shield]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: LICENSE

Base64 encoding and **strict** decoding in Rocq, following [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648),
proved correct in both directions:

```coq
Theorem decode_encode c bs : wf c -> decode c (encode c bs) = Some bs.
Theorem encode_decode c l bs : wf c -> decode c l = Some bs -> encode c bs = l.
```
The core theory is over `list Byte.byte`.

There are also bridges to MetaRocq's bytestrings, to the standard library's
`String.string` and to Rocq's primitive strings.

## Install
Currently, the author recommend using the nix-based setup. `nix-build` builds
the library against Rocq 9.1; `nix-build --argstr bundle 9.0` and
`--argstr bundle 9.2` build it against those, and all three run in CI.
TODO: upload to opam, and nixpkgs.


## Examples

```coq
From Base64 Require Import All.
From Stdlib Require Import Strings.String.   (* for list_byte_of_string *)

(* bytes *)
Compute encode standard (list_byte_of_string "any carnal pleasure").
     (* = list_byte_of_string "YW55IGNhcm5hbCBwbGVhc3VyZQ==" *)
Compute decode url (list_byte_of_string "Zm9vYg").
     (* = Some (list_byte_of_string "foob") *)

(* MetaRocq bytestrings *)
Compute encode_bs standard (BS.parse (list_byte_of_string "foobar")).

(* stdlib strings *)
Compute encode_str standard "foobar".   (* = "Zm9vYmFy"%string *)
Compute decode_str url "Zm9vYg".        (* = Some "foob"%string *)

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


## What "strict" means
`decode` has no malleability in the sense of [eprint 2022/361](https://eprint.iacr.org/2022/361.pdf).
`decode` only accepts correct inputs, returns `None` otherwise.

| Input | Why rejected |
|---|---|
| `"Zg==Z"` | length ≡ 1 mod 4 |
| `"Zg!="` | character outside the alphabet |
| `"Zg==Zg=="` | padding before the final quad |
| `"Z==="` | too little data before the padding |
| `"QR=="` | non-zero trailing bits (`"QQ=="` is the canonical form) |
| `"Zg"`, `"Zg="` | missing or short padding, under a padded config |
| `"Zg=="` under `url` | padding present, under an unpadded config |


## Modules

| Module | Contents |
|---|---|
| `Util` | `index_of` and the `list_ind3`/`list_ind4` induction principles |
| `Sextet` | the 6-bit word, and the 3↔4 byte/sextet repacking with its six inverse lemmas |
| `Alphabet` | `config`, `wf`, the shipped alphabets, `enc_sextet`/`dec_byte` |
| `Base64` | `encode`, `decode`, both roundtrip theorems, `encode_length`, `encode_charset`, `encode_app` |
| `MetaRocqString` | `encode_bs`/`decode_bs` over `MetaRocq.Utils.bytestring.String.t` |
| `StdStrings` | `encode_str`/`decode_str` over stdlib `String.string` |
| `PrimStrings` | `encode_ps`/`decode_ps` over `PrimString.string` |
| `Equiv` | the conversions between those three, and the `base64` rewrite database |
| `Tests` | RFC 4648 §10 vectors and the strictness cases above, checked by `make` |
| `All` | re-exports everything but `Tests` |

`Equiv` exports the tactic `base64_simpl`, which takes a goal over
bytestrings, stdlib strings or primitive strings down to one over `list byte`,
where `decode_encode` and `encode_decode` apply. See the comment above it in
`theories/Equiv.v`.

## Tests

`make difftest` extracts `encode`/`decode` to OCaml and compares them against
the Rust [`base64`](https://github.com/marshallpierce/rust-base64) crate on
~1.5M cases, all of which currently agree. It needs `rocq`, `ocamlopt` and
`cargo`; `nix-shell --argstr job base64-testsuite` provides all three.

The same comparison runs in CI as the `base64-testsuite` job, so it can also
be run as a package:

```sh
nix-build --argstr job base64-testsuite
```

That derivation (`.nix/rocq-overlays/base64-testsuite`) takes the crate from
`tests/reference/Cargo.lock` and the library from the `base64` package, which
is what lets it run in a sandbox without network access.


## Limitations
- `dec_byte` is a linear scan of a 64-element table, and the primitive-string
  path converts through `list byte`. Fine for moderate inputs; a
  `PrimInt63`-arithmetic fast path proved equal to the generic one is the
  obvious follow-up for large payloads.
- No streaming interface; `encode_app` is the only compositionality lemma.

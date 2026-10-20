# base64

[![Nix CI][nix-action-shield]][nix-action-link]
[![MIT License][license-shield]][license-link]

[nix-action-shield]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml/badge.svg?branch=main
[nix-action-link]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml
[license-shield]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: LICENSE

Base64 encoding and **strict** decoding in Rocq, following [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648).

The lemmas are provided on a `ByteString` type class, with instances for `list byte`, the stdlib's `String`, MetaRocq's `bytestring`,
and Rocq's `PrimString`.


## Install
This library is currently in an experimental stage.
The author uses the nix-based setup.


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
Compute encode standard (BS.parse (list_byte_of_string "foobar")).
Compute decode standard (BS.parse (list_byte_of_string "Zm9vYmFy")).

(* stdlib strings *)
Compute encode standard "foobar"%string.   (* = "Zm9vYmFy"%string *)
Compute decode url "Zm9vYg"%string.        (* = Some "foob"%string *)

(* primitive strings.  `All` only `Require`s `PrimString`, so that it does not
   shadow `String.string`; import it yourself to get the `"..."` literals. *)
From Stdlib Require Import Strings.PrimString.
Compute encode standard "foobar"%pstring.   (* = "Zm9vYmFy"%pstring *)
Compute decode url "Zm9vYg"%pstring.        (* = Some "foob"%pstring *)
```

There are three different variants of encoding a string in base64.

| Config       | 62 | 63 | Padded | RFC 4648 |
|--------------|----|----|--------|----------|
| `standard`   | `+` | `/` | yes | §4, "base64" |
| `url`        | `-` | `_` | no  | §5, "base64url" (JWT style) |
| `url_padded` | `-` | `_` | yes | §5 with padding |


## Modules

| Module | Contents |
|---|---|
| `Sextet` | the 6-bit word, and the 3↔4 byte/sextet repacking with its six inverse lemmas |
| `Alphabet` | `config`, `wf`, the shipped alphabets, `enc_sextet`/`dec_byte` |
| `Base64` | `encode`, `decode`, both roundtrip theorems, `encode_length`, `encode_charset`, `encode_app` |
| `MetaRocqString` | bytestring instance, byte-conversion laws and native encoded-length lemma |
| `StdStrings` | stdlib-string instance, byte-conversion laws and native encoded-length lemma |
| `PrimStrings` | primitive-string instance, conversions, capacity and native length lemmas |
| `Strings` | `ByteString`, byte conversions and `fits`, uniform `encode`/`decode`, and shared correctness proofs |

`Strings.decode_encode`, `Strings.encode_decode`, `Strings.decode_encode_iff`,
`Strings.encode_inj`, `Strings.encode_length`, and `Strings.encode_app` apply
to every instance.


## Tests
The test suits ensures that this library behaves as [base64 Rust library](https://crates.io/crates/base64).
```sh
nix-build --argstr job base64-testsuite
```

## What "strict" means
Other libraries are forgiving with slightly malformed inputs; the `decode` function of this library only accepts correct inputs.
`decode` has no malleability in the sense of [eprint 2022/361](https://eprint.iacr.org/2022/361.pdf).

Each case — bad length, a character outside the alphabet, padding before the
final quad, too little data before the padding, non-zero trailing bits, missing
or short padding, and padding under an unpadded config — is pinned down by an
`Example` in [`theories/Tests.v`](theories/Tests.v), so `make` checks them.


## Ideas for improvement
- Improve performance using `PrimInt63`-arithmetic to improve performance.
- Implement a streaming interface.

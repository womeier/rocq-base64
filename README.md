# base64

[![Nix CI][nix-action-shield]][nix-action-link]
[![MIT License][license-shield]][license-link]

[nix-action-shield]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml/badge.svg?branch=main
[nix-action-link]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml
[license-shield]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: LICENSE

Base64 encoding and **strict** decoding in Rocq, following [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648).


## Installation
The library is available via opam and nixpkgs.
```sh
opam repo add rocq-released https://rocq-prover.org/opam/released
opam install rocq-base64
```

## Examples
Supported string types are `list byte`, the stdlib's `String` and `PrimString`, and MetaRocq's `bytestring`.

### Byte list
```coq
From Base64 Require Import All.
From Stdlib Require Import Strings.String.   (* for list_byte_of_string *)

Compute encode standard (list_byte_of_string "the quick brown fox jumps").
     (* = list_byte_of_string "dGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcw==" *)
Compute decode url (list_byte_of_string "Zm9vYg").
     (* = Some (list_byte_of_string "foob") *)
```

### Stdlib string
```coq
From Base64 Require Import All.
From Stdlib Require Import Strings.String.

Compute encode standard "foobar"%string.   (* = "Zm9vYmFy"%string *)
Compute decode url "Zm9vYg"%string.        (* = Some "foob"%string *)
```

### Primitive string
```coq
From Base64 Require Import All.
From Stdlib Require Import Strings.PrimString.

Compute encode standard "foobar"%pstring.   (* = "Zm9vYmFy"%pstring *)
Compute decode url "Zm9vYg"%pstring.        (* = Some "foob"%pstring *)
```

### MetaRocq bytestring
```coq
From Base64 Require Import All.
From Base64 Require Import InstanceBytestring.
Import MetaRocq.Utils.bytestring.   (* for the "..."%bs literals *)

Compute encode standard "foobar"%bs.     (* = "Zm9vYmFy"%bs *)
Compute decode standard "Zm9vYmFy"%bs.   (* = Some "foobar"%bs *)
```

## Tests
The test suite ensures that this library behaves like the [base64 Rust library](https://crates.io/crates/base64).
```sh
nix-build --argstr job base64-testsuite
```
Either half runs on its own from the same job's shell, which installs the library both halves test against:
```sh
nix-shell --argstr job base64-testsuite --run 'make difftest importtest'
```

## Variants
A variant is determined by which characters encode 62 and 63, and whether the output is padded.
RFC 4648 names two alphabets: the standard `base64` (§4) and `base64url` (§5).
All four combinations ship:

| Config              | 62 | 63 | Padded | Short name | RFC 4648 | Rust `base64` |
|---------------------|----|----|--------|------------|----------|---------------|
| `standard_padded`   | `+` | `/` | yes | `standard` | "base64", §4 | `STANDARD` |
| `standard_unpadded` | `+` | `/` | no  | — | "base64", §4 unpadded per §3.2 | `STANDARD_NO_PAD` |
| `url_padded`        | `-` | `_` | yes | — | "base64url", §5 at §3.2's default | `URL_SAFE` |
| `url_unpadded`      | `-` | `_` | no  | `url` | "base64url", §5 unpadded per §3.2 (JWT style) | `URL_SAFE_NO_PAD` |

The short names are additional Rocq notations, as they are the most commonly used ones.


## What "strict" means
Other libraries are forgiving with slightly malformed inputs; the `decode` function of this library only accepts correct inputs.
`decode` has no malleability in the sense of [eprint 2022/361](https://eprint.iacr.org/2022/361.pdf).
See the examples in [`theories/Tests.v`](theories/Tests.v).


## Ideas for improvement
- Improve performance using `PrimInt63`-arithmetic.
- Implement a streaming interface.

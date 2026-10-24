# base64

[![Nix CI][nix-action-shield]][nix-action-link]
[![MIT License][license-shield]][license-link]

[nix-action-shield]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml/badge.svg?branch=main
[nix-action-link]: https://github.com/womeier/rocq-base64/actions/workflows/nix-action-9.1.yml
[license-shield]: https://img.shields.io/badge/license-MIT-blue.svg
[license-link]: LICENSE

Base64 encoding and **strict** decoding in Rocq, following [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648).

The lemmas are provided on a `ByteString` type class, with instances for `list byte`, the stdlib's `String`,
and Rocq's `PrimString`.

An instance for MetaRocq's `bytestring` lives in [`metarocq/`](metarocq/) and is installed by the
separate `rocq-base64-bytestring` package, so `rocq-base64` itself does **not** depend on MetaRocq.


## Install

```sh
# once, if you do not have Rocq from opam already
opam repo add rocq-released https://rocq-prover.org/opam/released
opam pin add rocq-base64 git+https://github.com/womeier/rocq-base64.git

# optional, for MetaRocq's bytestrings (pulls in MetaRocq)
opam pin add rocq-base64-bytestring git+https://github.com/womeier/rocq-base64.git
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


## Examples

```coq
From Base64 Require Import All.
From Stdlib Require Import Strings.String.   (* for list_byte_of_string *)

(* bytes *)
Compute encode standard (list_byte_of_string "any carnal pleasure").
     (* = list_byte_of_string "YW55IGNhcm5hbCBwbGVhc3VyZQ==" *)
Compute decode url (list_byte_of_string "Zm9vYg").
     (* = Some (list_byte_of_string "foob") *)

(* stdlib strings *)
Compute encode standard "foobar"%string.   (* = "Zm9vYmFy"%string *)
Compute decode url "Zm9vYg"%string.        (* = Some "foob"%string *)

(* primitive strings.  `All` only `Require`s `PrimString`, so that it does not
   shadow `String.string`; import it yourself to get the `"..."` literals. *)
From Stdlib Require Import Strings.PrimString.
Compute encode standard "foobar"%pstring.   (* = "Zm9vYmFy"%pstring *)
Compute decode url "Zm9vYg"%pstring.        (* = Some "foob"%pstring *)
```

`All` exports the generic `ByteString` API, so the bare `encode`/`decode` above always mean the
type-class versions. The core functions on `list byte` stay reachable as `Base64.encode` and
`Base64.decode`.

MetaRocq's bytestrings need the separate `rocq-base64-bytestring` package:

```coq
From Base64 Require Import All.
From Base64.MetaRocq Require Import Bytestring.

Compute encode standard (BS.parse (list_byte_of_string "foobar")).
Compute decode standard (BS.parse (list_byte_of_string "Zm9vYmFy")).
```

## Tests
The test suite ensures that this library behaves like the [base64 Rust library](https://crates.io/crates/base64).
```sh
nix-build --argstr job base64-testsuite

# extra job: builds the rocq-base64-bytestring package, bridge and tests included
nix-build --argstr job base64-bytestring
```

## What "strict" means
Other libraries are forgiving with slightly malformed inputs; the `decode` function of this library only accepts correct inputs.
`decode` has no malleability in the sense of [eprint 2022/361](https://eprint.iacr.org/2022/361.pdf).
See the examples in [`theories/Tests.v`](theories/Tests.v).


## Ideas for improvement
- Improve performance using `PrimInt63`-arithmetic.
- Implement a streaming interface.

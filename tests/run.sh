#!/usr/bin/env bash
# Differential test: the OCaml code extracted from theories/Base64.v against the
# Rust `base64` crate, on a corpus ported from that crate's own test suite.
# See tests/reference/src/main.rs for why that crate is the oracle.
#
# Run from a nix-shell (which provides rocq, ocaml, cargo and rustc):
#   make difftest      or      tests/run.sh
#
# Not part of CI: `cargo` needs to fetch the `base64` crate, and the nix build
# sandbox has no network.  Cargo.lock pins the exact version.
set -euo pipefail

cd "$(dirname "$0")/.."
root=$PWD
work=${TMPDIR:-/tmp}/rocq-base64-difftest.$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

say() { printf '\n== %s\n' "$*"; }

for tool in rocq ocamlopt ocamldep cargo; do
  command -v "$tool" >/dev/null || { echo "difftest: $tool not found in PATH" >&2; exit 1; }
done

say "building the library"
make -j"$(nproc)" >/dev/null

say "extracting theories/Base64.v to OCaml"
rm -rf tests/extracted
mkdir -p tests/extracted
rocq c -Q theories base64 tests/Extraction.v

say "compiling the extracted encoder/decoder"
cp tests/harness.ml tests/extracted/
cd tests/extracted
# The extracted .mli files only restrict what the harness can see; dropping
# them means ocamlopt needs no separate interface pass.
rm -f ./*.mli
ocamlopt -w -a -I . -o "$work/harness" $(ocamldep -sort ./*.ml) >/dev/null
cd "$root"

say "building the reference (base64 crate)"
cd tests/reference
cargo build --release --offline 2>/dev/null \
  || cargo build --release   # fall back to the network if the crate is not cached
cd "$root"
ref=tests/reference/target/release/b64ref

say "generating the corpus"
"$ref" cases > "$work/corpus"
wc -l < "$work/corpus" | xargs printf '   %s protocol lines\n'

say "running both implementations"
time "$work/harness" < "$work/corpus" > "$work/rocq.out"
time "$ref" respond   < "$work/corpus" > "$work/rust.out"

say "comparing"
if diff -q "$work/rocq.out" "$work/rust.out" >/dev/null; then
  echo "   OK: $(wc -l < "$work/rocq.out") results agree"
else
  echo "   MISMATCH -- first 40 differing cases (input, rocq, rust):"
  paste -d'\t' "$work/corpus" "$work/rocq.out" "$work/rust.out" \
    | awk -F'\t' '$2 != $3 { print }' | head -40
  n=$(paste -d'\t' "$work/corpus" "$work/rocq.out" "$work/rust.out" \
        | awk -F'\t' '$2 != $3' | wc -l)
  echo "   $n of $(wc -l < "$work/corpus") cases disagree"
  cp "$work/corpus" "$work/rocq.out" "$work/rust.out" /tmp/ 2>/dev/null || true
  exit 1
fi

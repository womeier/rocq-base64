#!/usr/bin/env bash
# Builds and checks the MetaRocq bytestring bridge in metarocq/MetaRocqString.v.
# Kept out of the installed rocq-base64 package (so depending on it does not
# pull in MetaRocq) and exercised only here, in CI.
#
# Run from a nix-shell providing rocq and metarocq-utils:
#   metarocq/run.sh
#
# BASE64_PREBUILT=1 lets a packager supply the already-installed library, so
# this skips `make` and the base64 `-Q` flag -- same convention as
# tests/run.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

say() { printf '\n== %s\n' "$*"; }

prebuilt=${BASE64_PREBUILT:-}

if [ -n "$prebuilt" ]; then
  say "using the installed library (found through ROCQPATH)"
  rocqflags=()
else
  say "building the library"
  make -j"$(nproc)" >/dev/null
  rocqflags=(-Q theories Base64)
fi

say "checking the MetaRocq bridge"
## In dependency order: Tests.v requires the instance from MetaRocqString.v.
for v in metarocq/MetaRocqString.v metarocq/Tests.v; do
  echo "   $v"
  rocq c ${rocqflags[@]+"${rocqflags[@]}"} -Q metarocq Base64Metarocq "$v"
done

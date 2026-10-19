# Test against the Rust `base64` crate
#
# nix-build --argstr job base64-testsuite
{
  lib,
  stdenv,
  base64,
  rocq-core,
  rustPlatform,
  cargo,
  rustc,
}:

let
  root = ../../..;

  ## Only `tests/`: the theories come from `base64`, and the generated
  ## artifacts (`tests/extracted`, `tests/reference/target`) must not leak
  ## from a working tree into the build.
  relative = path: lib.removePrefix "${toString root}/" (toString path);
  source = lib.cleanSourceWith {
    name = "rocq-base64-tests";
    src = root;
    filter =
      path: _type:
      let
        rel = relative path;
      in
      (rel == "tests" || lib.hasPrefix "tests/" rel)
      && !(lib.hasPrefix "tests/extracted" rel)
      && !(lib.hasPrefix "tests/reference/target" rel);
  };

  ## The oracle: the `base64` crate behind the protocol spoken by
  ## `tests/harness.ml`.  See `tests/reference/src/main.rs` for why that
  ## crate, and not Python's `base64`, is the right reference.
  reference = rustPlatform.buildRustPackage {
    pname = "b64ref";
    version = "0.1.0";

    src = lib.cleanSourceWith {
      name = "b64ref-source";
      src = root + "/tests/reference";
      filter = path: _type: baseNameOf (toString path) != "target";
    };
    cargoLock.lockFile = root + "/tests/reference/Cargo.lock";

    ## The crate's own tests are not the point here; `cases`/`respond` are.
    doCheck = false;

    meta.mainProgram = "b64ref";
  };
in

stdenv.mkDerivation {
  pname = "base64-testsuite";
  inherit (base64) version;

  src = source;

  nativeBuildInputs = [
    rocq-core.ocamlPackages.ocaml
    cargo
    rustc
  ];
  buildInputs = [
    rocq-core
    base64
  ];

  dontConfigure = true;
  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ## `tee` must not swallow a mismatch.
    set -o pipefail
    env BASE64_PREBUILT=1 B64REF=${lib.getExe reference} \
      bash tests/run.sh 2>&1 | tee difftest.log
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -D difftest.log $out/share/base64-testsuite/difftest.log
    runHook postInstall
  '';

  passthru = { inherit reference; };

  meta = {
    description = "Testing rocq-base64 against the Rust base64 crate";
    inherit (base64.meta) maintainers license;
  };
}

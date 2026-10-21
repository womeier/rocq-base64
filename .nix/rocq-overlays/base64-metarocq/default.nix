# The MetaRocq bytestring bridge
#
# The bridge is not part of the installed `base64` package -- that package must
# not drag MetaRocq in -- so it is built here instead, against the installed
# library.  This is what keeps MetaRocq in CI.
#
# nix-build --argstr job base64-metarocq
{
  lib,
  stdenv,
  base64,
  rocq-core,
  metarocq-utils,
}:

let
  root = ../../..;

  ## Only `metarocq/`: the theories come from `base64`, and the build must not
  ## pick up `.vo` files left behind in a working tree.
  relative = path: lib.removePrefix "${toString root}/" (toString path);
  source = lib.cleanSourceWith {
    name = "rocq-base64-metarocq";
    src = root;
    filter =
      path: _type:
      let
        rel = relative path;
      in
      (rel == "metarocq" || lib.hasPrefix "metarocq/" rel)
      && !(lib.hasSuffix ".vo" rel)
      && !(lib.hasSuffix ".vos" rel)
      && !(lib.hasSuffix ".vok" rel)
      && !(lib.hasSuffix ".glob" rel);
  };
in

stdenv.mkDerivation {
  pname = "base64-metarocq";
  inherit (base64) version;

  src = source;

  buildInputs = [
    rocq-core
    base64
    metarocq-utils
    # MetaRocq.Utils loads the Equations plugin, so findlib must assemble
    # OCAMLPATH from the propagated plugin site-libs.
    rocq-core.ocamlPackages.findlib
  ];

  dontConfigure = true;

  ## `metarocq/run.sh` would rebuild the library; here it is already installed
  ## and on ROCQPATH, which is what BASE64_PREBUILT selects.
  buildPhase = ''
    runHook preBuild
    ## `tee` must not swallow a failure.
    set -o pipefail
    env BASE64_PREBUILT=1 bash metarocq/run.sh 2>&1 | tee metarocq.log
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D metarocq.log $out/share/base64-metarocq/metarocq.log
    runHook postInstall
  '';

  meta = {
    description = "The MetaRocq bytestring bridge for rocq-base64";
    inherit (base64.meta) maintainers license;
  };
}

# The MetaRocq bytestring bridge: the `rocq-base64-bytestring` package
#
# The bridge is not part of the `base64` package -- that package must not drag
# MetaRocq in -- so it is built and installed here instead, on top of the
# installed library.  This is what keeps MetaRocq in CI, and it exercises the
# packaging path (`make bytestring` / `make install-bytestring`) that
# rocq-base64-bytestring.opam uses.
#
# nix-build --argstr job base64-bytestring
{
  lib,
  stdenv,
  base64,
  rocq-core,
  metarocq-utils,
}:

let
  root = ../../..;

  ## Only `metarocq/` and the Makefile: the theories come from `base64`, and
  ## the build must not pick up `.vo` files left behind in a working tree.
  relative = path: lib.removePrefix "${toString root}/" (toString path);
  source = lib.cleanSourceWith {
    name = "rocq-base64-bytestring";
    src = root;
    filter =
      path: _type:
      let
        rel = relative path;
      in
      (rel == "Makefile" || rel == "metarocq" || lib.hasPrefix "metarocq/" rel)
      && !(lib.hasSuffix ".vo" rel)
      && !(lib.hasSuffix ".vos" rel)
      && !(lib.hasSuffix ".vok" rel)
      && !(lib.hasSuffix ".glob" rel);
  };
in

stdenv.mkDerivation {
  pname = "base64-bytestring";
  inherit (base64) version;

  src = source;

  buildInputs = [
    rocq-core
    # MetaRocq.Utils loads the Equations plugin, so findlib must assemble
    # OCAMLPATH from the propagated plugin site-libs.
    rocq-core.ocamlPackages.findlib
  ];

  ## Both are needed to *use* the bridge, so pass them on to anything that
  ## depends on this package.
  propagatedBuildInputs = [
    base64
    metarocq-utils
  ];

  dontConfigure = true;

  ## `base64` is already installed and on ROCQPATH, which is where the
  ## `bytestring` target expects to find it; `theories/` is not even in `src`.
  buildFlags = [ "bytestring" ];

  installTargets = [ "install-bytestring" ];
  installFlags = [
    "COQLIBINSTALL=${placeholder "out"}/lib/coq/${rocq-core.rocq-version}/user-contrib"
  ];

  meta = {
    description = "MetaRocq bytestring support for rocq-base64";
    inherit (base64.meta) maintainers license;
  };
}

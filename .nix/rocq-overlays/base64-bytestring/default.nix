# The MetaRocq bytestring bridge: the `rocq-base64-bytestring` package
#
# The bridge is not part of the `base64` package -- that package must not drag
# MetaRocq in -- so it is built and installed here instead, on top of the
# installed library.  This is what keeps MetaRocq in CI, and it builds through
# the same `make -C bytestring` that rocq-base64-bytestring.opam uses.
#
# nix-build --argstr job base64-bytestring
{
  stdenv,
  base64,
  rocq-core,
  metarocq-utils,
}:

stdenv.mkDerivation {
  pname = "base64-bytestring";

  ## One checkout, one revision: the two packages are built from the same tree,
  ## so they share the fetch rather than each describing the source again.
  ## Locally that is the toolbox's `fetchGit` of this repo; in nixpkgs it is the
  ## release tarball.  Either way it carries no build output of its own.
  inherit (base64) version src;

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

  ## Only `bytestring/` is built, and `bytestring/_RocqProject` binds just
  ## `-Q theories Base64.MetaRocq`: `Base64` is resolved through ROCQPATH, from
  ## the installed `base64`, never from the `theories/` that share this source.
  makeFlags = [ "-C" "bytestring" ];

  installFlags = [
    "COQLIBINSTALL=${placeholder "out"}/lib/coq/${rocq-core.rocq-version}/user-contrib"
  ];

  meta = {
    description = "MetaRocq bytestring support for rocq-base64";
    inherit (base64.meta) maintainers license;
  };
}

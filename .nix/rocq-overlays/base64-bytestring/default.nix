# The MetaRocq bytestring bridge: the `rocq-base64-bytestring` package
#
# The bridge is not part of the `base64` package -- that package must not drag
# MetaRocq in -- so it is built and installed here instead, on top of the
# installed library.  This is what keeps MetaRocq in CI, and it builds through
# the same `make -C bytestring` that rocq-base64-bytestring.opam uses.
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

  ## Only `bytestring/`: the theories come from `base64`.
  ##
  ## The `.vo` exclusions are load-bearing here and nowhere else.  For its one
  ## configured `attribute` (`base64`) the toolbox injects the local sources by
  ## overriding `version` with a `fetchGit` of this repo, which copies tracked
  ## files only -- but there is no such mechanism for a second local package,
  ## so this one builds its src from a plain path, and a plain path includes
  ## gitignored files.  A `.vo` that arrives that way reads as up to date (the
  ## store stamps every file with the same mtime), so `make` would skip the
  ## recompile and install the stale artefact.  Omit these lines in the nixpkgs
  ## expression, where src is a release tarball and cannot carry build output.
  relative = path: lib.removePrefix "${toString root}/" (toString path);
  source = lib.cleanSourceWith {
    name = "rocq-base64-bytestring";
    src = root;
    filter =
      path: _type:
      let
        rel = relative path;
      in
      (rel == "bytestring" || lib.hasPrefix "bytestring/" rel)
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
  makeFlags = [ "-C" "bytestring" ];

  installFlags = [
    "COQLIBINSTALL=${placeholder "out"}/lib/coq/${rocq-core.rocq-version}/user-contrib"
  ];

  meta = {
    description = "MetaRocq bytestring support for rocq-base64";
    inherit (base64.meta) maintainers license;
  };
}

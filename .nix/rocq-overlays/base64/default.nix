{
  lib,
  mkRocqDerivation,
  stdlib,
  metarocq-utils,
  rocq-core,
  version ? null,
}:

with lib;
mkRocqDerivation {
  pname = "base64";
  repo = "rocq-base64";
  owner = "womeier";

  inherit version;
  defaultVersion =
    with versions;
    switch
      [ rocq-core.rocq-version ]
      [
        {
          cases = [ (range "9.0" "9.3") ];
          out = "0.1.0";
        }
      ]
      null;

  release."0.1.0".sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  propagatedBuildInputs = [
    stdlib
    metarocq-utils
    # MetaRocq.Utils loads the Equations plugin, so findlib must assemble
    # OCAMLPATH from the propagated plugin site-libs.
    rocq-core.ocamlPackages.findlib
  ];

  releaseRev = v: "v${v}";

  meta = {
    description = "Verified RFC 4648 base64 encoding and decoding in Rocq";
    maintainers = with maintainers; [ womeier ];
    license = licenses.mit;
  };
}

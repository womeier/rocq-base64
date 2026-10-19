{
  lib,
  mkRocqDerivation,
  stdlib,
  rocq-core,
  metarocq-utils,
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

  # Both are needed to *use* the library: a consumer that `Require`s
  # `Base64.InstanceBytestring` loads a `.vo` that transitively needs
  # `MetaRocq.Utils.bytestring`, so metarocq-utils must be on their ROCQPATH
  # too.  Mirrors the `rocq-metarocq-utils` entry in rocq-base64.opam.
  propagatedBuildInputs = [
    stdlib
    metarocq-utils
  ];

  # MetaRocq.Utils loads the Equations plugin, so findlib must assemble
  # OCAMLPATH from the propagated plugin site-libs.
  buildInputs = [ rocq-core.ocamlPackages.findlib ];

  releaseRev = v: "v${v}";

  meta = {
    description = "Verified RFC 4648 base64 encoding and decoding in Rocq";
    maintainers = with maintainers; [ womeier ];
    license = licenses.mit;
  };
}

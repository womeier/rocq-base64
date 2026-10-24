{
  lib,
  mkRocqDerivation,
  stdlib,
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

  # No MetaRocq here: the bytestring bridge ships as its own package, so this
  # one stays stdlib-only.  See `.nix/rocq-overlays/base64-bytestring`.
  propagatedBuildInputs = [ stdlib ];

  releaseRev = v: "v${v}";

  meta = {
    description = "Verified RFC 4648 base64 encoding and decoding in Rocq";
    maintainers = with maintainers; [ womeier ];
    license = licenses.mit;
  };
}

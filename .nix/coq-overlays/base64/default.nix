{
  lib,
  mkCoqDerivation,
  coq,
  metarocq,
  version ? null,
}:

with lib;
mkCoqDerivation {
  pname = "base64";
  repo = "rocq-base64";
  owner = "womeier";

  inherit version;
  releaseRev = v: "v${v}";

  ## Nothing is released yet, so there is no `defaultVersion`/`release`; the
  ## toolbox overrides `src` with the local checkout.
  defaultVersion = null;

  ## Only `MetaRocq.Utils` is used, so take the `utils` subpackage rather than
  ## all of MetaRocq.
  propagatedBuildInputs = [ metarocq.utils ];

  meta = {
    description = "Verified RFC 4648 base64 encoding and decoding in Rocq";
    maintainers = with maintainers; [ womeier ];
    license = licenses.mit;
  };
}

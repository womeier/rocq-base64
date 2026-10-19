{
  ## DO NOT CHANGE THIS
  format = "1.0.0";
  ## unless you made an automated or manual update
  ## to another supported format.

  attribute = "base64";

  ## `nix-shell` builds this instead, which is `base64` plus the toolchain the
  ## differential test needs (ocaml, cargo, rustc).  See tests/run.sh.
  shell-attribute = "base64-difftest";

  ## MetaRocq is still packaged under `coqPackages`, not `rocqPackages`.
  no-rocq-yet = true;

  default-bundle = "9.1";

  ## Rocq 9.1 only: that is the version MetaRocq 1.5.1 is packaged for, and the
  ## version CertiRocq pins.
  bundles."9.1" = {
    coqPackages = {
      coq.override.version = "9.1";
      metarocq.job = true;
      metarocq.override.version = "9.1";
    };
    rocqPackages = {
      rocq-core.override.version = "9.1";
    };
  };

  bundles."9.1".push-branches = [ "main" ];

  ## Cachix caches to use in CI
  cachix.coq = { };
  cachix.coq-community = { };
  cachix.metarocq = { };

  cachix.metarocq.authToken = "CACHIX_AUTH_TOKEN";
}

{
  ## DO NOT CHANGE THIS
  format = "1.0.0";

  attribute = "base64";

  default-bundle = "9.1";

  ## Each bundle pins three things, and all three matter:
  ##  - `rocq-core`, the compiler the library is built with;
  ##  - `coq`, the legacy-compat attribute.  nixpkgs defines it as
  ##    `callPackage ../applications/science/logic/coq { inherit (rocq-core) version; }`
  ##    where `rocq-core` is the *function argument*, so overriding
  ##    `rocqPackages.rocq-core` alone leaves it at the base set's version and
  ##    every bundle would build MetaRocq (an `mkCoqDerivation` package)
  ##    against Rocq 9.1, whose `.vo` files no other Rocq can load;
  ##  - `metarocq`, because nixpkgs only knows releases up to 1.5.1-9.1 and
  ##    picks one by `coq.coq-version`; 9.2 needs the matching upstream tag.
  ## `coq` and `metarocq` are mentioned only to be pinned; they are built as
  ## dependencies of `base64`, so they do not need CI jobs of their own.
  bundles."9.0" = {
    rocqPackages.rocq-core.override.version = "9.0";
    rocqPackages.coq.override.version = "9.0";
    rocqPackages.coq.job = false;
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };
  bundles."9.1" = {
    rocqPackages.rocq-core.override.version = "9.1";
    rocqPackages.coq.override.version = "9.1";
    rocqPackages.coq.job = false;
    ## The differential test against the Rust `base64` crate; see
    ## `.nix/rocq-overlays/base64-testsuite`.
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };
  bundles."9.2" = {
    rocqPackages.rocq-core.override.version = "9.2";
    rocqPackages.coq.override.version = "9.2";
    rocqPackages.coq.job = false;
    rocqPackages.metarocq.override.version = "v1.5.1-9.2";
    rocqPackages.metarocq.job = false;
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };


  ## Cachix caches to use in CI
  ## Below we list some standard ones
  cachix.coq = {};
  cachix.math-comp = {};
  cachix.coq-community = {};
  
  ## If you have write access to one of these caches you can
  ## provide the auth token or signing key through a secret
  ## variable on GitHub. Then, you should give the variable
  ## name here. For instance, coq-community projects can use
  ## the following line instead of the one above:
  # cachix.coq-community.authToken = "CACHIX_AUTH_TOKEN";
  
  ## Or if you have a signing key for a given Cachix cache:
  # cachix.my-cache.signingKey = "CACHIX_SIGNING_KEY"
  
  ## Note that here, CACHIX_AUTH_TOKEN and CACHIX_SIGNING_KEY
  ## are the names of secret variables. They are set in
  ## GitHub's web interface.
}

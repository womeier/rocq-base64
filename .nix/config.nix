{
  ## DO NOT CHANGE THIS
  format = "1.0.0";

  attribute = "base64";

  default-bundle = "9.2";

  ## CI bundles
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
    ## The differential test against the Rust `base64` crate
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };
  bundles."9.2" = {
    rocqPackages.rocq-core.override.version = "9.2";
    rocqPackages.coq.override.version = "9.2";
    rocqPackages.coq.job = false;
    ## nixpkgs' metarocq has no defaultVersion past coq 9.1, which makes
    ## `metarocq-utils` (= `metarocq.utils`) evaluate as -broken.  Naming the
    ## upstream tag is what un-breaks it; base64 needs it now that
    ## InstanceBytestring.v is part of the library.
    rocqPackages.metarocq.override.version = "v1.5.1-9.2";
    rocqPackages.metarocq.job = false;
    ## The differential test against the Rust `base64` crate
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };
  bundles."9.3" = {
    rocqPackages.rocq-core.override.version = "9.3";
    rocqPackages.coq.override.version = "9.3";
    rocqPackages.coq.job = false;
    ## MetaRocq has released no 9.3 tag yet (newest is v1.5.1-9.2, and Rocq
    ## 9.3.0 shipped 2026-09-19), so this pins the head of upstream's `9.3`
    ## branch by commit.  Replace it with the tag once one exists.
    rocqPackages.metarocq.override.version = "16c0778c9098bbb7f5bf57a85e495a3520fe8026";
    rocqPackages.metarocq.job = false;
    ## The differential test against the Rust `base64` crate
    rocqPackages.base64-testsuite.job = true;
    push-branches = [ "main" ];
  };


  ## Cachix caches to use in CI
  ## Below we list some standard ones
  cachix.coq = {};
  cachix.math-comp = {};
  cachix.coq-community = {};
  cachix.metacoq = {};
  
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

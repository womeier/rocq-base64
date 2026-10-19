{
  ## DO NOT CHANGE THIS
  format = "1.0.0";

  attribute = "base64";

  default-bundle = "9.1";
  bundles."9.0" = {
    rocqPackages.rocq-core.override.version = "9.0";
    push-branches = [ "main" ];
  };
  bundles."9.1" = {
    rocqPackages.rocq-core.override.version = "9.1";
    push-branches = [ "main" ];
  };
  bundles."9.2" = {
    rocqPackages.rocq-core.override.version = "9.2";
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

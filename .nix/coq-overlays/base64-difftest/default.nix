## `base64` plus the toolchain `tests/run.sh` needs.  This is the
## `shell-attribute` from `.nix/config.nix`, so `nix-shell` drops you into an
## environment where `make difftest` works; the library itself does not depend
## on any of it.
{
  base64,
  ocaml,
  cargo,
  rustc,
}:

base64.overrideAttrs (o: {
  pname = "base64-difftest";
  nativeBuildInputs = (o.nativeBuildInputs or [ ]) ++ [
    ocaml
    cargo
    rustc
  ];
})

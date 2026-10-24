all: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq all

clean: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq cleanall
	@rm -f Makefile.rocq Makefile.rocq.conf
	@if [ -f Makefile.bytestring ]; then \
	  $(MAKE) -f Makefile.bytestring cleanall; \
	fi
	@rm -f Makefile.bytestring Makefile.bytestring.conf

Makefile.rocq: _RocqProject
	$(COQBIN)rocq makefile -f _RocqProject -o Makefile.rocq

# Differential test against the Rust `base64` crate, on a corpus ported from
# that crate's own test suite.  Needs ocaml, cargo and rustc:
# `nix-shell --argstr job base64-testsuite` provides them.  CI runs the same
# comparison through that job (`nix-build --argstr job base64-testsuite`),
# which vendors the crate from Cargo.lock instead of fetching it.
difftest:
	@tests/run.sh

# The MetaRocq bytestring instance in `bytestring/`, built and installed as the
# separate `rocq-base64-bytestring` opam package (see rocq-base64-bytestring.opam).
# It is deliberately not part of `all`: the rocq-base64 package must not depend
# on MetaRocq.
#
# This compiles against the *installed* library, found through ROCQPATH, never
# against `theories/` -- that is what keeps the two packages independent, and
# why the flags are spelled out here instead of reusing
# `bytestring/_RocqProject`, whose `-Q ../theories Base64` line exists for
# editors only.  Needs the library and metarocq-utils in ROCQPATH:
# `nix-shell --argstr job base64-bytestring --run "make bytestring"` provides
# both, and CI builds the whole package through that same job
# (`nix-build --argstr job base64-bytestring`).
BYTESTRING_V := $(wildcard bytestring/*.v)

Makefile.bytestring: $(BYTESTRING_V)
	$(COQBIN)rocq makefile -Q bytestring Base64.MetaRocq $(BYTESTRING_V) -o Makefile.bytestring

bytestring: Makefile.bytestring
	@+$(MAKE) -f Makefile.bytestring all

install-bytestring: Makefile.bytestring
	@+$(MAKE) -f Makefile.bytestring install

force _RocqProject Makefile $(BYTESTRING_V): ;

%: Makefile.rocq force
	@+$(MAKE) -f Makefile.rocq $@

.PHONY: all clean force difftest bytestring install-bytestring

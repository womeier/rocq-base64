all: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq all

clean: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq cleanall
	@rm -f Makefile.rocq Makefile.rocq.conf

Makefile.rocq: _RocqProject
	$(COQBIN)rocq makefile -f _RocqProject -o Makefile.rocq

# Differential test against the Rust `base64` crate, on a corpus ported from
# that crate's own test suite.  Needs ocaml, cargo and rustc:
# `nix-shell --argstr job base64-testsuite` provides them.  CI runs the same
# comparison through that job (`nix-build --argstr job base64-testsuite`),
# which vendors the crate from Cargo.lock instead of fetching it.
difftest:
	@tests/run.sh

# The MetaRocq bytestring instance.  It is deliberately not part of `all`: the
# installed package must not depend on MetaRocq, so it lives in `metarocq/` and
# is checked separately.  Needs metarocq-utils in ROCQPATH:
# `nix-shell --argstr job base64-metarocq --run "make metarocq"` provides it.
# CI runs the same check through that job (`nix-build --argstr job
# base64-metarocq`), against the installed library.
metarocq:
	@metarocq/run.sh

force _RocqProject Makefile: ;

%: Makefile.rocq force
	@+$(MAKE) -f Makefile.rocq $@

.PHONY: all clean force difftest metarocq

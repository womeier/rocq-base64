all: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq all

clean: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq cleanall
	@rm -f Makefile.rocq Makefile.rocq.conf

Makefile.rocq: _RocqProject
	$(COQBIN)rocq makefile -f _RocqProject -o Makefile.rocq

# Differential test against the Rust `base64` crate, on a corpus ported from
# that crate's own test suite.
difftest:
	@tests/run.sh

# Compile the README's examples, this should only be run inside nix
importtest:
	@for f in tests/import_test_*.v; do \
	  printf '\n== %s\n' "$$f"; \
	  $(COQBIN)rocq c "$$f"; \
	done

force _RocqProject Makefile: ;

%: Makefile.rocq force
	@+$(MAKE) -f Makefile.rocq $@

.PHONY: all clean force difftest importtest

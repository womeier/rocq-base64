# The MetaRocq bytestring instance: its own package (rocq-base64-bytestring),
# so its own makefile.  Run it from here (`make -C bytestring`) or through the
# top-level `bytestring` / `install-bytestring` targets.
#
# `Base64` is resolved through ROCQPATH, from the installed library -- never
# from ../theories, which is what keeps the two packages independent.  Needs
# the library and metarocq-utils there: `nix-shell --argstr job
# base64-bytestring` provides both, and CI builds this package through that
# same job (`nix-build --argstr job base64-bytestring`).

all: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq all

clean: Makefile.rocq
	@+$(MAKE) -f Makefile.rocq cleanall
	@rm -f Makefile.rocq Makefile.rocq.conf

Makefile.rocq: _RocqProject
	$(COQBIN)rocq makefile -f _RocqProject -o Makefile.rocq

force _RocqProject Makefile: ;

%: Makefile.rocq force
	@+$(MAKE) -f Makefile.rocq $@

.PHONY: all clean force

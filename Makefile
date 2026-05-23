VERSION = 0.1.0
LLVM_VERSION = 14
OCAML_VERSION = 4.14.2   # OCaml 5.x is incompatible with llvm.14.0.6 (NNP constraint)
LLVM_CONFIG = /opt/homebrew/opt/llvm@$(LLVM_VERSION)/bin/llvm-config

.PHONY: setup build run clean test install uninstall

# Cai dat moi truong lan dau
setup:
	brew install llvm@$(LLVM_VERSION) opam
	opam init --no-setup -y
	opam switch create $(OCAML_VERSION) -y
	eval $$(opam env) && \
	  LLVM_CONFIG=$(LLVM_CONFIG) \
	  opam install -y dune llvm.$(LLVM_VERSION).0.6

build:
	eval $$(opam env) && dune build

# Chay mot file .vn
# make run FILE=test/hello.vn
run: build
	eval $$(opam env) && \
	  ./_build/default/bin/main.exe $(FILE) && \
	  lli $$(basename $(FILE) .vn).ll

# Chay tat ca test
test: build
	@for f in test/*.vn; do \
	  echo "=== $$f ==="; \
	  eval $$(opam env) && ./_build/default/bin/main.exe $$f; \
	  lli $$(basename $$f .vn).ll; \
	done

# Bien dich thanh binary (can llc + gcc)
compile: build
	eval $$(opam env) && ./_build/default/bin/main.exe $(FILE) -o /tmp/out.ll
	llc /tmp/out.ll -o /tmp/out.s
	gcc /tmp/out.s -o /tmp/vnlang_out
	/tmp/vnlang_out

install: build
	chmod +x vnlangc
	ln -sf $(PWD)/vnlangc ~/.local/bin/vnlangc
	@echo "Installed: vnlangc -> ~/.local/bin/vnlangc"
	@echo "Usage: vnlangc <file.vn> [--run]"

uninstall:
	rm -f ~/.local/bin/vnlangc
	@echo "Uninstalled vnlangc"

clean:
	dune clean
	rm -f *.ll

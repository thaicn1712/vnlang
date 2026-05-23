# VNLang

A compiled programming language with Vietnamese keywords, built from scratch in **OCaml** with **LLVM** as the backend.

```
vnlangc main.vn --run
```

**Version:** v0.1.0 — see [CHANGELOG.md](CHANGELOG.md) for history and migration notes.

---

## What it is

VNLang is a statically-typed language that compiles to native machine code via LLVM IR.
The entire compiler — lexer, parser, codegen — is written in OCaml (~400 lines).

```
source (.vn)  →  Lexer  →  Parser  →  Codegen  →  LLVM IR (.ll)  →  native binary
```

Detailed explanation of each stage: [docs/01-kien-truc.md](docs/01-kien-truc.md)

---

## Language syntax

### Variables

```
bien x = 42
bien name = "Alice"
bien flag = dung
```

### Functions

```
ham add(a: so, b: so): so {
    tra_ve a + b
}

bien result = add(10, 20)
in(result)
```

### If / else

```
neu (result > 25) {
    in("greater than 25")
} khong {
    in("25 or less")
}
```

### Arithmetic & comparison

```
bien a = 10
bien b = 3

in(a + b)    # 13
in(a - b)    # 7
in(a * b)    # 30
in(a / b)    # 3  (integer division)
in(a == b)   # 0  (false)
in(a > b)    # 1  (true)
```

### Comments

```
# This is a comment — everything after # is ignored
```

---

## Keywords

| Keyword | Meaning | Example |
|---|---|---|
| `bien` | declare variable | `bien x = 5` |
| `ham` | define function | `ham f(a: so): so { ... }` |
| `tra_ve` | return | `tra_ve x + 1` |
| `neu` | if | `neu (x > 0) { ... }` |
| `khong` | else | `} khong { ... }` |
| `in` | print to stdout | `in(x)` |
| `dung` | true (boolean) | `bien ok = dung` |
| `sai` | false (boolean) | `bien ok = sai` |

---

## Types

| VNLang type | LLVM type | Size | Range / Notes |
|---|---|---|---|
| `so` | `i64` | 8 bytes | −2⁶³ to 2⁶³−1, signed integer |
| `chu` | `i8*` | 8 bytes (pointer) | null-terminated string, read-only |
| `logic` | `i1` | 1 bit | `dung` (1) or `sai` (0) |

Function return type is declared after `:`. A function with no meaningful return can use `so` and `tra_ve 0`.

---

## Install

### Requirements

| Tool | Version | Install |
|---|---|---|
| Homebrew | any | https://brew.sh |
| LLVM | 14.0.6 | `brew install llvm@14` |
| opam | 2.x | `brew install opam` |
| OCaml | **4.14.2** | via opam (see below) |
| dune | 3.x | via opam |

> **Why OCaml 4.14, not 5.x?**
> The `llvm.14.0.6` opam package uses C stubs with "naked pointers", which violates
> OCaml 5.x's no-naked-pointers (NNP) invariant. OCaml 4.14 is the current LTS and
> fully compatible. See [CHANGELOG.md](CHANGELOG.md) for the upgrade path.

### Step-by-step

```bash
# 1. Install system dependencies
brew install llvm@14 opam

# 2. Initialize opam and create an OCaml 4.14.2 switch
opam init --no-setup -y
opam switch create 4.14.2 -y
eval $(opam env)

# 3. Install OCaml packages (takes 5–15 min, compiles LLVM bindings)
export LLVM_CONFIG=/opt/homebrew/opt/llvm@14/bin/llvm-config
opam install -y dune llvm.14.0.6

# 4. Build the compiler
cd /path/to/vnlang
make build

# 5. Install the vnlangc command (adds to ~/.local/bin)
make install
```

### Verify

```bash
vnlangc           # should print usage
ocaml --version   # → 4.14.2
```

---

## Usage

### Compile a file

```bash
vnlangc main.vn
```

Produces `main.ll` (LLVM IR text) in the current directory.

### Compile and run immediately

```bash
vnlangc main.vn --run
```

Compiles to `main.ll` then runs it with `lli` (LLVM JIT interpreter) — no binary produced.

### Specify output path

```bash
vnlangc main.vn -o /tmp/out.ll
```

### Compile to native binary

```bash
vnlangc main.vn
llc main.ll -o main.s          # LLVM IR → assembly
gcc main.s -o main             # assembly → binary
./main
```

### Inspect the generated IR

```bash
vnlangc main.vn
cat main.ll
```

### Makefile targets

```bash
make build                     # compile the compiler itself
make install                   # symlink vnlangc into ~/.local/bin
make run FILE=test/hello.vn    # compile + run a test file
make test                      # run all files in test/
make clean                     # remove build artifacts and .ll files
make uninstall                 # remove vnlangc from ~/.local/bin
```

---

## How the compiler works

The compiler is a four-stage pipeline. Each stage is a pure function:

```
string  →[Lexer]→  token list  →[Parser]→  AST  →[Codegen]→  llmodule
```

### Stage 1 — Lexer (`lib/lexer.ml`)

Scans the source character-by-character and emits a flat list of tokens.

```
"bien x = 5 + 3"
→ [Bien, Ident "x", Eq, Int 5, Plus, Int 3, EOF]
```

- O(n) time, one pass
- Handles: numbers, identifiers, keywords, strings, operators, comments
- `tra_ve` is read as one token because `_` is treated as a letter

Full details: [docs/02-lexer.md](docs/02-lexer.md)

### Stage 2 — Parser (`lib/parser.ml`)

Converts the token list into an Abstract Syntax Tree using **recursive descent** (LL(1) strategy).

```
[Int 1, Plus, Int 2, Star, Int 3]
→
BinOp(Add, IntLit 1, BinOp(Mul, IntLit 2, IntLit 3))
```

Each grammar rule is one OCaml function. Operator precedence is encoded structurally — `parse_sum` calls `parse_term`, so `*` always binds tighter than `+`.

Full details: [docs/03-ast-parser.md](docs/03-ast-parser.md)

### Stage 3 — AST (`lib/ast.ml`)

Pure OCaml types, no logic. The tree for `bien x = 1 + 2 * 3`:

```
VarDecl("x",
  BinOp(Add,
    IntLit 1,
    BinOp(Mul, IntLit 2, IntLit 3)))
```

### Stage 4 — Codegen (`lib/codegen.ml`)

Walks the AST and emits LLVM IR. Two passes:

1. **Pass 1** — generate all `ham` (user functions) first
2. **Pass 2** — wrap top-level statements in a `main()` function

Key decisions:
- Variables use `alloca` (stack slots) so they can be reassigned
- `in()` calls `printf` from libc, format string chosen by inspecting `Llvm.type_of`
- `neu`/`khong` becomes `br` + basic blocks with a merge point

Full details: [docs/04-llvm-ir.md](docs/04-llvm-ir.md)

---

## Project structure

```
vnlang/
├── bin/
│   └── main.ml              CLI entry point
├── lib/
│   ├── ast.ml               AST type definitions
│   ├── lexer.ml / .mli      Lexer
│   ├── parser.ml / .mli     Parser
│   └── codegen.ml / .mli    LLVM IR generator
├── test/
│   ├── hello.vn             Basic print
│   ├── arithmetic.vn        Variables and operators
│   └── functions.vn         Functions, if/else, bool return
├── main.vn                  Demo program
├── vnlangc                  Shell wrapper script
├── Makefile
├── dune-project
├── VERSION                  0.1.0
├── CHANGELOG.md             Version history, LLVM migration notes
└── docs/
    ├── 01-kien-truc.md      Architecture and how to run (start here)
    ├── 02-lexer.md          Lexer internals
    ├── 03-ast-parser.md     AST, LL(1), recursive descent
    ├── 04-llvm-ir.md        LLVM IR, SSA, basic blocks, optimization
    ├── 05-ma-may.md         x86-64 / ARM64, registers, stack frames
    ├── 06-bieu-dien-bit.md  Bit/byte representation of each type
    └── 07-nghien-cuu.md     Research notes, type theory, references
```

---

## Known limitations (v0.1.0)

- No loops (`vong` — planned v0.2.0)
- No arrays or structs (planned v0.3.0)
- No type inference — function signatures must be fully annotated
- No mutual recursion — functions must be defined before they are called
- Variables declared in `main` are not accessible inside user functions (different scopes)
- No error recovery — the compiler stops at the first error with no position info

---

## Roadmap

| Version | Change type | Planned features |
|---|---|---|
| v0.2.0 | MINOR | `vong` while-loop, string concatenation, error messages with line numbers |
| v0.3.0 | MINOR | Arrays, basic struct/record type, import from C |
| v1.0.0 | MAJOR | Type inference (Hindley-Milner), module system, pattern matching, stable ABI |

---

## Documentation index

| Doc | Read when... |
|---|---|
| [01-kien-truc.md](docs/01-kien-truc.md) | You want to understand the full pipeline and how to run |
| [02-lexer.md](docs/02-lexer.md) | You want to understand tokenization |
| [03-ast-parser.md](docs/03-ast-parser.md) | You want to understand grammar and AST structure |
| [04-llvm-ir.md](docs/04-llvm-ir.md) | You want to read and understand the `.ll` output |
| [05-ma-may.md](docs/05-ma-may.md) | You want to understand what happens at the CPU level |
| [06-bieu-dien-bit.md](docs/06-bieu-dien-bit.md) | You want to understand how values are stored in memory |
| [07-nghien-cuu.md](docs/07-nghien-cuu.md) | You want theory, comparisons, and references |

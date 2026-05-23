# 01 — Architecture & How to Run

## Quick Start

```bash
# Compile and run in one step
vnlangc main.vn --run

# Compile only (produces main.ll)
vnlangc main.vn

# Run the produced IR with the LLVM interpreter
lli main.ll

# Compile to a native binary
llc main.ll -o main.s
gcc main.s -o main
./main
```

---

## The Full Pipeline

```
main.vn  (source text)
   │
   │  vnlangc
   ▼
┌─────────────────────────────────────────────────────────┐
│  bin/main.ml  — CLI entry point                          │
│  1. reads the .vn file into a string                     │
│  2. calls Lexer.tokenize                                 │
│  3. calls Parser.parse                                   │
│  4. calls Codegen.compile                                │
│  5. calls Llvm.print_module → writes main.ll             │
└─────────────────────────────────────────────────────────┘
   │
   ▼
main.ll  (LLVM IR — human-readable assembly-like text)
   │
   │  lli (LLVM JIT interpreter)        OR     llc + gcc
   ▼                                           ▼
stdout / result                            main (native binary)
```

Each stage is a pure function: it takes one data structure and returns the next.

```
string  →[Lexer]→  token list  →[Parser]→  AST  →[Codegen]→  llmodule
```

---

## Stage 1 — Lexer (`lib/lexer.ml`)

### What it does

Reads the source string character-by-character and emits a flat list of **tokens**.

A token is the smallest meaningful unit — like a word in natural language.

```
"bien x = 5 + 3"
→ [Bien, Ident "x", Eq, Int 5, Plus, Int 3, EOF]
```

### How it works internally

The lexer is a simple **state machine** with one mutable cursor (`pos : int`):

```
while pos < length(src):
  ch = src[pos]
  match ch:
    whitespace / '#'  → skip
    digit             → read_number  (consumes digits and optional '.')
    letter / '_'      → read_ident   (then check keyword table)
    '"'               → read_string  (handle escape sequences)
    '='               → peek next: '=' → EqEq, else Eq
    '!' → '='         → Neq
    '<' → optional '='→ Lt or Lte
    '>' → optional '='→ Gt or Gte
    '+' '-' '*' '/' ( ) { } : ,  → single-char tokens
emit EOF
```

### Keyword resolution

After reading a full identifier, the lexer checks a lookup list:

```ocaml
let keywords = [
  "bien", Bien;  "ham", Ham;  "tra_ve", TraVe;
  "neu",  Neu;   "khong", Khong;  "in", InKw;
  "so",   SoKw;  "chu",  ChuKw;  "logic", LogicKw;
  "dung", Dung;  "sai",  Sai;
]
```

`tra_ve` works correctly because `_` is treated as a letter — the whole word is read before checking.

### Complexity

- Time: **O(n)** — each character read exactly once
- Space: **O(n)** — the token list has at most n/1 tokens

---

## Stage 2 — Parser (`lib/parser.ml`)

### What it does

Takes the flat token list and builds a **tree** that reflects the structure and precedence of the program.

```
[Int 1, Plus, Int 2, Star, Int 3]
→
BinOp(Add,
  IntLit 1,
  BinOp(Mul, IntLit 2, IntLit 3))
```

### Strategy: Recursive Descent

Each grammar rule maps to one OCaml function. The functions call each other recursively, following the grammar.

```ocaml
parse_expr
  └─ parse_comparison
       └─ parse_sum          ← handles + and -
            └─ parse_term    ← handles * and /
                 └─ parse_factor   ← handles unary -
                      └─ parse_atom   ← literal, ident, call, (expr)
```

### How operator precedence works

The tree structure encodes precedence — no explicit precedence table needed.

`parse_sum` calls `parse_term` for each operand. Because `parse_term` handles `*`/`/` internally, multiplication always binds tighter than addition.

```
1 + 2 * 3:
  parse_sum sees 1, then +, then calls parse_term
    parse_term sees 2, then *, then 3 → returns Mul(2,3)
  parse_sum gets Add(1, Mul(2,3))   ← correct tree
```

### LL(1) property

The parser always knows which branch to take by looking at just the **current token**, no backtracking:

```
current token    →  which rule to apply
─────────────────────────────────────────
Bien             →  var_decl
Ham              →  func_decl
Neu              →  if_stmt
TraVe            →  return_stmt
Int/Float/Ident  →  expr_stmt
```

### Complexity

- Time: **O(n)** — each token consumed once
- Space: **O(d)** where d = maximum nesting depth (call stack)

---

## Stage 3 — AST (`lib/ast.ml`)

The AST (Abstract Syntax Tree) is just OCaml types. No logic — pure data.

```ocaml
type expr =
  | IntLit of int          (* 42 *)
  | FloatLit of float      (* 3.14 *)
  | BoolLit of bool        (* dung / sai *)
  | StringLit of string    (* "hello" *)
  | Var of string          (* x *)
  | BinOp of binop * expr * expr   (* a + b *)
  | Neg of expr            (* -x *)
  | Call of string * expr list     (* f(a, b) *)

type stmt =
  | VarDecl  of string * expr
  | FuncDecl of string * (string * typ) list * typ * stmt list
  | If       of expr * stmt list * stmt list option
  | Return   of expr
  | ExprStmt of expr
```

The tree for `bien x = 1 + 2 * 3`:

```
VarDecl("x",
  BinOp(Add,
    IntLit 1,
    BinOp(Mul, IntLit 2, IntLit 3)))
```

---

## Stage 4 — Codegen (`lib/codegen.ml`)

### What it does

Walks the AST and emits **LLVM IR instructions** into an in-memory module.

### Two-pass strategy

```
Pass 1:  generate all ham (function) definitions first
         → so they can be called from anywhere below

Pass 2:  wrap all top-level statements in a main() function
         → main() is what the OS calls when the binary runs
```

This is why you can define `ham square(...)` after using it in the source — the compiler sees all functions first.

### Key codegen decisions

**Variables use `alloca` (stack slots):**
```llvm
; bien x = 5
%x = alloca i64        ; reserve 8 bytes on stack
store i64 5, i64* %x   ; write 5 into that slot
; later: Var "x"
%x_val = load i64, i64* %x  ; read from slot
```

Why not just use SSA registers directly? Because variables need to be mutable — you can reassign them. Allocas are pointers to stack memory; you write and read through the pointer.

**Functions map 1-to-1 to LLVM functions:**
```
ham add(a: so, b: so): so  →  define i64 @add(i64 %a, i64 %b)
```

Parameters are also stored in allocas at the function start, for consistency.

**`in()` calls `printf` from libc:**
```llvm
declare i32 @printf(i8*, ...)    ; declaration of C's printf

; in(x) where x is i64:
%fmt = ... "%lld\n"
call i32 @printf(i8* %fmt, i64 %x_val)
```

The codegen inspects `Llvm.type_of v` to pick the right format string: `%lld` for i64, `%f` for double, `%s` for string pointer.

**`neu`/`khong` creates basic blocks:**
```llvm
; neu (cond) { A } khong { B }
  br i1 %cond, label %then, label %else
then:
  ; code for A
  br label %merge
else:
  ; code for B
  br label %merge
merge:
  ; execution continues here
```

### Environment

The codegen carries an `env` record through every call:

```ocaml
type env = {
  ctx       : Llvm.llcontext;   (* LLVM context — owns all types/values *)
  mdl       : Llvm.llmodule;    (* the module being built *)
  builder   : Llvm.llbuilder;   (* cursor: where to insert next instruction *)
  vars      : (string, var_info) Hashtbl.t;   (* name → alloca + type *)
  funcs     : (string, llvalue * ...) Hashtbl.t;  (* name → function *)
  cur_func  : llvalue option;   (* which function we're inside, if any *)
  printf_fn : llvalue;          (* reference to declared printf *)
  ...
}
```

---

## Output: LLVM IR (`.ll` file)

The `.ll` file is plain text — you can read it:

```bash
cat main.ll
```

Example output for `bien x = 5 \n in(x + 3)`:

```llvm
; Module vnlang

@fmt = private unnamed_addr constant [6 x i8] c"%lld\0A\00"

declare i32 @printf(i8* noundef, ...)

define i32 @main() {
entry:
  %x = alloca i64
  store i64 5, i64* %x
  %x1 = load i64, i64* %x
  %add = add i64 %x1, 3
  %fmt2 = getelementptr inbounds [6 x i8], [6 x i8]* @fmt, i64 0, i64 0
  call i32 (i8*, ...) @printf(i8* %fmt2, i64 %add)
  ret i32 0
}
```

---

## From `.ll` to native binary

```
main.ll
  │
  │  llc main.ll -o main.s          (LLVM static compiler)
  ▼
main.s  (x86-64 or ARM64 assembly text)
  │
  │  gcc main.s -o main             (assembler + linker)
  ▼
main   (ELF/Mach-O binary, runs natively)
  │
  │  ./main                         (OS loads and executes)
  ▼
output on stdout
```

Or skip all of that and use the LLVM JIT:
```
main.ll  →  lli main.ll  →  output   (interprets IR directly, no file produced)
```

---

## File layout

```
vnlang/
├── bin/
│   └── main.ml        CLI: reads file, calls pipeline, writes .ll
├── lib/
│   ├── ast.ml         AST type definitions (pure data, no logic)
│   ├── lexer.ml       Stage 1: string → token list
│   ├── lexer.mli      Public interface of lexer
│   ├── parser.ml      Stage 2: token list → AST
│   ├── parser.mli     Public interface of parser
│   ├── codegen.ml     Stage 3: AST → Llvm.llmodule
│   └── codegen.mli    Public interface of codegen
├── test/
│   ├── hello.vn       Basic print test
│   ├── arithmetic.vn  Operators and variables
│   └── functions.vn   Functions, if/else, bool return
├── main.vn            Quick demo program
├── vnlangc            Shell wrapper — makes `vnlangc` work as a command
├── Makefile           build / install / test targets
├── dune-project       Dune build system config
├── VERSION            0.1.0
├── CHANGELOG.md       Version history and LLVM migration notes
└── docs/
    ├── 01-kien-truc.md    ← this file: architecture + how to run
    ├── 02-lexer.md        Lexer theory
    ├── 03-ast-parser.md   AST and parser theory
    ├── 04-llvm-ir.md      LLVM IR deep dive
    ├── 05-ma-may.md       Machine code (x86-64, ARM64)
    ├── 06-bieu-dien-bit.md  Bit/byte representation
    └── 07-nghien-cuu.md   Research notes and references
```

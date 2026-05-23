# 07 – Research Notes & Kiến thức nền

## Lý thuyết ngôn ngữ hình thức (Formal Language Theory)

### Chomsky Hierarchy

| Loại | Grammar | Automaton | Ví dụ |
|---|---|---|---|
| Type 3 | Regular | Finite Automaton (FSM) | Regex, token patterns |
| Type 2 | Context-Free (CFG) | Pushdown Automaton | Hầu hết ngôn ngữ lập trình |
| Type 1 | Context-Sensitive | Linear Bounded Automaton | Ít dùng |
| Type 0 | Unrestricted | Turing Machine | Mọi thứ |

VNLang dùng **Type 2 (CFG)** – đủ mạnh cho hầu hết ngôn ngữ lập trình.

### FIRST và FOLLOW sets

Để verify grammar là LL(1), cần tính:

**FIRST(X)** = tập token có thể bắt đầu một chuỗi derived từ X.

```
FIRST(stmt) = {Bien, Ham, Neu, TraVe, Int, Float, Str, Ident, InKw, LParen, Minus, Dung, Sai}
FIRST(var_decl) = {Bien}
FIRST(func_decl) = {Ham}
```

**FOLLOW(X)** = tập token có thể xuất hiện ngay sau X.

Grammar là **LL(1)** nếu với mỗi non-terminal A và production A → α | β:
```
FIRST(α) ∩ FIRST(β) = ∅
```
(không nhập nhằng: nhìn 1 token là biết dùng rule nào)

## So sánh các chiến lược parsing

### LL(1) – Recursive Descent (VNLang dùng)
- Đơn giản, dễ implement
- Error messages tốt (biết chính xác đang expect gì)
- Hạn chế: không handle left-recursive grammar, ambiguous grammar
- Ví dụ: Python parser, GCC trước version 4

### LALR(1) – Menhir, Yacc, Bison
- Mạnh hơn LL(1): handle nhiều grammar hơn
- Dùng parse table được generate trước
- Error messages khó đọc hơn
- Ví dụ: Ruby, PHP, GCC

### Earley / GLR – Ambiguous grammars
- Handle mọi CFG, kể cả ambiguous
- O(n³) worst case
- Ví dụ: Haskell's GHC (dùng Alex + Happy LALR)

### Pratt Parsing – Expression parsing
- Rất tốt cho expression với many precedence levels
- Thay vì recursive grammar levels, dùng "binding power" numbers
- Ví dụ: Rust's parser dùng Pratt cho expressions

## Type Systems

VNLang v0.1.0: **Explicitly typed** (khai báo kiểu bắt buộc cho hàm)

### Hindley-Milner (HM) – planned v1.0.0

Type inference mạnh nhất cho functional languages:
```
let cong a b = a + b
(* HM suy ra: cong : int -> int -> int *)
```

Algorithm W: unification-based.

### Subtyping (như Java, Scala)
```
class Animal
class Dog extends Animal
val a: Animal = new Dog()  -- OK, Dog là subtype của Animal
```

### Dependent Types (Agda, Idris, Coq)
- Type có thể phụ thuộc vào value
- Có thể prove programs correct in the type system
- Rất phức tạp

## Memory Models

### Stack allocation (VNLang v0.1.0 dùng)
- `alloca` → biến sống trên stack của function call
- Tự động free khi function return
- Nhanh: chỉ cần `sub rsp, n`
- Hạn chế: không thể return pointer đến local variable (dangling pointer)

### Heap allocation
- `malloc`/`free` (C), `new`/`delete` (C++)
- Sống lâu hơn function
- Cần quản lý: memory leaks nếu quên free

### Garbage Collection (GC)
- OCaml: minor heap (generational GC) + major heap
- Java: G1GC, ZGC
- Không cần free thủ công, nhưng GC pause

### Ownership (Rust)
- Compile-time borrow checker
- Zero-cost: không GC, không manual free
- Phức tạp để học

## LLVM Architecture chi tiết

```
Source Language
      │
      ▼
  Frontend (Clang, VNLang, etc.)
      │ LLVM IR
      ▼
  ┌─────────────────────────┐
  │  LLVM Middle End         │
  │  - mem2reg pass          │
  │  - constant folding      │
  │  - dead code elimination │
  │  - loop optimizations    │
  │  - inlining              │
  └──────────┬──────────────┘
             │ optimized LLVM IR
             ▼
  ┌─────────────────────────┐
  │  LLVM Backend           │
  │  - instruction selection│
  │  - register allocation  │
  │  - scheduling           │
  └──────────┬──────────────┘
             │ Machine code
             ▼
  x86-64 / ARM64 / RISC-V / WASM / ...
```

### Pass Manager

LLVM tổ chức optimization thành **passes**:

```ocaml
(* Chạy optimization passes *)
let pm = Llvm.PassManager.create () in
Llvm_scalar_opts.add_memory_to_register_promotion pm;  (* mem2reg *)
Llvm_scalar_opts.add_dead_store_elimination pm;
ignore (Llvm.PassManager.run_module mdl pm)
```

## OCaml và LLVM

Tại sao OCaml tốt cho viết compiler?

1. **Algebraic Data Types** – pattern matching trên AST rất tự nhiên:
   ```ocaml
   match expr with
   | IntLit n -> ...
   | BinOp(Add, l, r) -> ...
   ```

2. **Immutability by default** – ít bug hơn khi xử lý tree traversal

3. **Strong type system** – OCaml compiler bắt nhiều bug tại compile time

4. **Garbage collected** – không lo memory management trong compiler logic

5. **Pattern exhaustiveness** – OCaml warning nếu match thiếu case

## Tài liệu tham khảo

### Books
- "Crafting Interpreters" – Robert Nystrom (free online, rất hay)
- "Engineering a Compiler" – Cooper & Torczon
- "Modern Compiler Implementation in ML" – Andrew Appel
- "Types and Programming Languages" – Pierce (type theory)

### LLVM
- LLVM Language Reference: https://llvm.org/docs/LangRef.html
- LLVM OCaml bindings: https://llvm.moe/ocaml/
- Kaleidoscope tutorial (LLVM's official tutorial): https://llvm.org/docs/tutorial/

### OCaml
- Real World OCaml (free online): https://dev.realworldocaml.org/
- OCaml manual: https://v2.ocaml.org/manual/

### Formal Language Theory
- "Introduction to Automata Theory, Languages, and Computation" – Hopcroft, Ullman
- "Compilers: Principles, Techniques, and Tools" – Aho, Lam, Sethi, Ullman (Dragon Book)

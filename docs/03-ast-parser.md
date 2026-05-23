# 03 – AST & Parser

## AST là gì?

**Abstract Syntax Tree** = cây biểu diễn cấu trúc của chương trình,
đã loại bỏ chi tiết cú pháp (dấu ngoặc, khoảng trắng, từ khóa trống).

### Ví dụ

Source:
```
bien x = 1 + 2 * 3
```

AST:
```
VarDecl("x",
  BinOp(Add,
    IntLit 1,
    BinOp(Mul, IntLit 2, IntLit 3)))
```

Lý do `Mul` nằm sâu hơn `Add`: **precedence** (ưu tiên nhân trước cộng).
Parser xây dựng cây này theo đúng thứ tự ưu tiên.

## Cấu trúc AST (ast.ml)

```
typ   = TSo | TChu | TLogic | TVoid
binop = Add | Sub | Mul | Div | Eq | Neq | Lt | Gt | Lte | Gte

expr =
  | IntLit int          ← 42
  | FloatLit float      ← 3.14
  | BoolLit bool        ← dung / sai
  | StringLit string    ← "xin chao"
  | Var string          ← x  (đọc biến)
  | BinOp(op, l, r)    ← l + r
  | Neg expr            ← -x
  | Call(f, args)       ← cong(1, 2)

stmt =
  | VarDecl(name, expr)           ← bien x = ...
  | FuncDecl(name, params, ret, body)  ← ham f(...): so { ... }
  | If(cond, then, else?)         ← neu (...) { } khong { }
  | Return expr                   ← tra_ve ...
  | ExprStmt expr                 ← biểu thức đứng một mình
```

## Parser là gì?

Parser nhận token list → xây dựng AST.
Chiến lược: **Recursive Descent** (LL(1)).

### Recursive Descent

Mỗi non-terminal trong grammar = 1 hàm OCaml:

```
grammar rule                 OCaml function
─────────────────────────    ──────────────
program  ::= stmt* EOF       parse_program
stmt     ::= var_decl | ...  parse_stmt
sum      ::= term (± term)*  parse_sum
atom     ::= INT | IDENT | ( expr_stmt )  parse_atom
```

### Ví dụ: parse `1 + 2 * 3`

```
parse_expr
  → parse_comparison
    → parse_sum
        parse_term  → parse_factor → parse_atom → IntLit 1  ✓
        thấy '+', loop:
          parse_term
            parse_factor → parse_atom → IntLit 2  ✓
            thấy '*', loop:
              parse_factor → parse_atom → IntLit 3  ✓
            → BinOp(Mul, IntLit 2, IntLit 3)
          → BinOp(Add, IntLit 1, BinOp(Mul,...))
```

## Operator Precedence qua cấu trúc grammar

```
sum  → term (+/- term)*     ← ưu tiên thấp
term → factor (*// factor)*  ← ưu tiên cao hơn
```

Vì `term` được gọi bên trong `sum`, nhân/chia tự nhiên "kết chặt hơn" cộng/trừ.
Không cần bảng ưu tiên hay Pratt parser – cấu trúc đệ quy tự encode precedence.

## LL(1) là gì?

**L**eft-to-right scan, **L**eftmost derivation, **1** lookahead token.

Có nghĩa: parser luôn quyết định nên đi nhánh nào chỉ dựa vào **token hiện tại**
mà không cần nhìn lại hay nhìn xa hơn.

```
Thấy token Bien  → chắc chắn là var_decl
Thấy token Ham   → chắc chắn là func_decl
Thấy token Neu   → chắc chắn là if_stmt
Thấy token Int/Ident/... → expr_stmt
```

Đây là lý do grammar được thiết kế cẩn thận:
mỗi nhánh bắt đầu bằng token khác nhau (no ambiguity).

## Điều kiện LL(1)

Grammar là LL(1) nếu:
- Với mỗi non-terminal, các nhánh của nó có **FIRST set rời nhau**
- FIRST(var_decl) = {Bien}, FIRST(func_decl) = {Ham}, ... → OK

Nếu không thỏa mãn (ambiguous grammar), cần dùng LALR(1) như Menhir.

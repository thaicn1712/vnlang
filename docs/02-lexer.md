# 02 – Lexer (Phân tích từ vựng)

## Nhiệm vụ

Chuyển **chuỗi ký tự** thành **danh sách token** có nghĩa.
Loại bỏ: khoảng trắng, comment (`#...`).

```
"bien x = 5 + 3"
  →  [Bien, Ident "x", Eq, Int 5, Plus, Int 3, EOF]
```

## Token là gì?

Token = đơn vị ngữ nghĩa nhỏ nhất của ngôn ngữ.
Tương tự: từ trong câu văn.

| Token | Ký tự trong source | Kiểu OCaml |
|---|---|---|
| `Bien` | `bien` | keyword |
| `Ham` | `ham` | keyword |
| `Int 42` | `42` | literal |
| `Float 3.14` | `3.14` | literal |
| `Str "hello"` | `"hello"` | literal |
| `Ident "x"` | `x` (tên biến/hàm) | identifier |
| `Plus` | `+` | operator |
| `EqEq` | `==` | operator |
| `EOF` | (hết file) | sentinel |

## Thuật toán

Lexer là **state machine** đơn giản, đọc từng ký tự:

```
while có ký tự:
  bỏ qua whitespace, comment
  nhìn ký tự hiện tại:
    - digit → đọc number (int hoặc float)
    - letter/_ → đọc identifier → kiểm tra keyword
    - '"' → đọc string (xử lý escape)
    - '+' → emit Plus
    - '=' → nhìn tiếp: '=' → EqEq, ngược lại → Eq
    - ... etc.
emit EOF
```

Độ phức tạp: **O(n)** – mỗi ký tự đọc đúng 1 lần.

## Xử lý keyword

Sau khi đọc một identifier, kiểm tra trong `keywords` list:

```ocaml
let keywords = [
  "bien", Bien;  "ham", Ham;  "tra_ve", TraVe; ...
]
(* tra_ve được đọc nguyên cả underscore vì '_' là alnum *)
```

`tra_ve` hoạt động đúng vì `_` thuộc nhóm `is_alpha`.

## Xử lý string

```
"xin chao\n"
```

Lexer đọc từ ký tự sau `"` đến `"` đóng:
- `\\n` → `\n` (newline thực)
- `\\t` → tab
- `\\"` → dấu nháy trong string
- `\\\\` → backslash thực

## Multi-char operators

`==`, `!=`, `<=`, `>=` cần **lookahead 1 ký tự**:

```ocaml
| '=' ->
    adv s;
    match cur s with
    | Some '=' -> adv s; push EqEq
    | _        -> push Eq
```

Đây là lý do lexer này là LL(1) – chỉ cần nhìn trước 1 ký tự.

## Comment

`#` bắt đầu một line comment – bỏ qua đến hết dòng:

```ocaml
| Some '#' ->
    while (match cur s with Some '\n' | None -> false | _ -> true) do adv s done
```

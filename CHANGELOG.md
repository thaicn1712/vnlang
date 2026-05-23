# CHANGELOG – VNLang

Dùng [Semantic Versioning](https://semver.org): MAJOR.MINOR.PATCH
- MAJOR: breaking change (syntax, binary format, incompatible API)
- MINOR: tính năng mới, backwards-compatible
- PATCH: bug fix

---

## [0.1.0] – 2025-01-23  ← CURRENT

### Added
- Lexer: tokenize source tiếng Việt (không dấu)
- Parser: recursive-descent LL(1), hỗ trợ:
  - `bien` khai báo biến
  - `ham` định nghĩa hàm với tham số có kiểu
  - `neu / khong` if/else
  - `tra_ve` return
  - `in(...)` print builtin
  - Biểu thức số học: `+ - * /`
  - So sánh: `== != < > <= >=`
- Codegen: sinh LLVM IR (target LLVM 14.x)
  - `so` → i64, `chu` → i8*, `logic` → i1
  - Hàm top-level được wrap vào `main()`
  - Print tự nhận dạng kiểu runtime qua `Llvm.type_of`
- Kiểu: `so`, `chu`, `logic`
- Output: file `.ll` (LLVM IR text), chạy bằng `lli`

### Limitations (known, sẽ fix trong các version sau)
- Không có type inference: hàm phải khai báo kiểu đầy đủ
- Không có closures / higher-order functions
- Biến top-level không accessible từ bên trong hàm (khác scope)
- Không hỗ trợ mutual recursion (hàm phải khai báo trước khi dùng)
- Không có loop (`vong lap` – planned v0.2.0)
- Không có mảng / struct – planned v0.3.0

---

## [0.2.0] – planned

### Impact: MINOR (thêm syntax mới, không break code cũ)

### Planned
- `vong (dieu_kien) { }` – while loop
- `cho (bien i = 0) (i < 10) (i = i + 1) { }` – for loop
- String concatenation với `+`
- `== ` cho string (strcmp)
- Multiple return values (tuple cơ bản)

---

## [0.3.0] – planned

### Impact: MINOR

### Planned
- Mảng: `bien a = [1, 2, 3]`, truy cập `a[0]`
- Struct / record type
- Import hàm từ C

---

## [1.0.0] – planned

### Impact: MAJOR (có thể break syntax hiện tại)

### Planned
- Type inference (Hindley-Milner)
- Module system
- Pattern matching
- Stable ABI

---

## LLVM Migration Notes

### 14 → 15+ (opaque pointers)

| LLVM 14 | LLVM 15+ |
|---|---|
| `Llvm.build_call fn args name b` | `Llvm.build_call2 fn_ty fn args name b` |
| `Llvm.build_load ptr name b` | `Llvm.build_load2 elem_ty ptr name b` |
| `Llvm.pointer_type elem_ty` | `Llvm.pointer_type ctx` |

Các vị trí cần thay đổi trong `codegen.ml` đã được đánh dấu comment `(* LLVM 15+: ... *)`.

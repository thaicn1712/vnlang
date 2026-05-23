# 04 – LLVM IR

## LLVM IR là gì?

LLVM IR (Intermediate Representation) là một **ngôn ngữ assembly cấp cao**,
platform-independent. Nó giống assembly nhưng:
- Có types (i64, double, i1, i8*)
- Có vô hạn "virtual registers" (dạng `%name`)
- Không phụ thuộc CPU cụ thể

LLVM IR → (llc) → x86-64 assembly → native binary.

## Ví dụ: VNLang → LLVM IR

### VNLang source
```
bien x = 5
in(x + 3)
```

### LLVM IR được sinh ra (đã đơn giản hóa)

```llvm
@fmt_int = private constant [6 x i8] c"%lld\0A\00"

declare i32 @printf(i8*, ...)

define i32 @main() {
entry:
  ; bien x = 5
  %x = alloca i64           ; cấp phát 8 bytes trên stack
  store i64 5, i64* %x      ; ghi giá trị 5 vào &x

  ; x + 3
  %x_val = load i64, i64* %x          ; đọc x từ stack
  %add = add i64 %x_val, 3            ; cộng

  ; in(...)
  %fmt = getelementptr [6 x i8], [6 x i8]* @fmt_int, i64 0, i64 0
  call i32 (i8*, ...) @printf(i8* %fmt, i64 %add)

  ret i32 0
}
```

## Khái niệm cốt lõi của LLVM IR

### SSA (Static Single Assignment)

Mỗi virtual register chỉ được **gán một lần**:
```llvm
%x = add i64 1, 2     ; OK
%x = add i64 3, 4     ; LỖI: %x đã được gán rồi
```

Đây là tại sao để có mutable variable, ta dùng `alloca` + `store`/`load`:
```llvm
%x_ptr = alloca i64       ; x_ptr là địa chỉ (luôn bất biến)
store i64 5, i64* %x_ptr  ; thay đổi giá trị tại địa chỉ đó
%val = load i64, i64* %x_ptr  ; đọc lại
```

### Basic Block

Hàm được chia thành **basic blocks** – chuỗi instruction không có nhảy ở giữa.
Mỗi block kết thúc bằng một **terminator**: `ret`, `br`, `cond_br`.

```llvm
define i64 @abs(i64 %n) {
entry:
  %cond = icmp slt i64 %n, 0
  br i1 %cond, label %negative, label %positive

negative:
  %neg = sub i64 0, %n
  br label %exit

positive:
  br label %exit

exit:
  %result = phi i64 [ %neg, %negative ], [ %n, %positive ]
  ret i64 %result
}
```

### Các instruction quan trọng

| Instruction | Ý nghĩa |
|---|---|
| `alloca i64` | Cấp phát 8 bytes trên stack, trả về `i64*` |
| `store i64 5, i64* %p` | Ghi 5 vào địa chỉ %p |
| `load i64, i64* %p` | Đọc giá trị i64 từ địa chỉ %p |
| `add i64 %a, %b` | Cộng nguyên |
| `fadd double %a, %b` | Cộng float |
| `icmp slt i64 %a, %b` | So sánh nguyên có dấu, trả về i1 |
| `br label %bb` | Nhảy vô điều kiện |
| `br i1 %c, label %t, label %f` | Nhảy có điều kiện |
| `call i32 @printf(...)` | Gọi hàm |
| `ret i64 %val` | Return |
| `phi i64 [%a, %bb1], [%b, %bb2]` | Chọn giá trị theo block đến |

## Types trong LLVM

| LLVM type | Kích thước | VNLang type |
|---|---|---|
| `i1` | 1 bit (pad thành 8 bit) | `logic` |
| `i8` | 1 byte | byte, char |
| `i32` | 4 bytes | int32 |
| `i64` | 8 bytes | `so` |
| `double` | 8 bytes, IEEE 754 | float |
| `i8*` | 8 bytes (pointer) | `chu` (string) |
| `[n x i8]` | n bytes | string constant |

## Optimization passes

LLVM có hàng trăm optimization passes. Các passes quan trọng:

- **mem2reg**: chuyển `alloca`/`store`/`load` → thuần SSA registers.
  Đây là lý do ta dùng alloca cho biến thay vì SSA trực tiếp.
- **inlining**: inline hàm nhỏ
- **constant folding**: `1 + 2` → `3` tại compile time
- **dead code elimination**: xóa code không bao giờ chạy

Chạy optimization: `opt -O2 input.ll -o opt.ll`

## Từ .ll đến binary

```
.vn → (vnlang compiler) → .ll (LLVM IR text)
                               ↓ llc
                           .s (assembly, e.g. x86-64)
                               ↓ gcc / clang
                           binary (ELF/Mach-O)
```

Hoặc JIT với `lli`:
```
.ll → (lli: LLVM JIT) → chạy thẳng, không tạo file
```

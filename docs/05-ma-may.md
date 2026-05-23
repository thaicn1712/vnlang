# 05 – Mã máy (Machine Code)

## Mã máy là gì?

Mã máy = chuỗi bytes mà CPU đọc và thực thi trực tiếp.
Mỗi instruction = 1–15 bytes (trên x86-64).

```
LLVM IR:     add i64 %a, %b
x86-64 asm:  add rax, rbx
mã máy:      48 01 D8     (3 bytes)
```

## x86-64 Architecture (Intel/AMD Mac, Linux)

### Registers (thanh ghi)

```
64-bit  32-bit  16-bit  8-bit   Công dụng
──────  ──────  ──────  ─────   ─────────────────────────────
rax     eax     ax      al      Kết quả trả về (return value)
rbx     ebx     bx      bl      Callee-saved (hàm được gọi phải bảo toàn)
rcx     ecx     cx      cl      Tham số thứ 4 (System V ABI)
rdx     edx     dx      dl      Tham số thứ 3
rsi     esi     si      sil     Tham số thứ 2
rdi     edi     di      dil     Tham số thứ 1
rsp     esp     sp      spl     Stack pointer (đỉnh stack)
rbp     ebp     bp      bpl     Base pointer (đáy frame)
r8–r15                          Tham số 5–6, general purpose
```

### System V AMD64 ABI (Linux / macOS)

Khi gọi hàm `f(a, b, c, d, e, f)`:
```
a → rdi
b → rsi
c → rdx
d → rcx
e → r8
f → r9
kết quả → rax
```

Nếu có nhiều hơn 6 tham số → push lên stack.

### Stack frame

```
High address
  ┌─────────────────┐
  │ caller's frame   │
  ├─────────────────┤ ← rbp (base pointer, tùy chọn)
  │ saved rbp        │
  │ local var 1      │ (alloca → sub rsp, 8)
  │ local var 2      │
  │ ...              │
  ├─────────────────┤ ← rsp (stack pointer, luôn trỏ top)
Low address (stack grows down)
```

### Ví dụ: bien x = 5

```
; LLVM IR
%x = alloca i64
store i64 5, i64* %x

; x86-64 assembly (sau llc)
sub rsp, 8        ; cấp phát 8 bytes (1 i64) trên stack
mov qword ptr [rsp], 5  ; ghi 5 vào địa chỉ rsp
```

### Ví dụ: cong(a, b) gọi hàm

```
; VNLang
bien ket = cong(3, 4)

; x86-64
mov edi, 3        ; a = 3 (tham số 1 vào rdi)
mov esi, 4        ; b = 4 (tham số 2 vào rsi)
call cong         ; gọi hàm, rax chứa kết quả
mov [rsp-8], rax  ; lưu ket
```

### Ví dụ: neu/khong (if/else)

```
; VNLang
neu (x > 0) { in("duong") } khong { in("am") }

; x86-64
cmp rax, 0        ; so sánh x với 0
jg  .then         ; jump if greater
; else block:
lea rdi, [rel "am"]
call printf
jmp .merge
.then:
lea rdi, [rel "duong"]
call printf
.merge:
```

## ARM64 Architecture (Apple Silicon M1/M2/M3)

Nếu bạn dùng Mac M1/M2/M3, LLVM sinh ARM64:

```
Registers: x0–x30 (64-bit), w0–w30 (32-bit)
x0: tham số 1 / return value
x1: tham số 2
... x7: tham số 8
sp: stack pointer
lr: link register (return address)
```

ARM64 là RISC – mỗi instruction cố định **4 bytes**:

```
; add i64 %a, %b
ADD X0, X0, X1   ; 4 bytes: 8B 00 01 8B (little-endian)
```

## Call instruction hoạt động như thế nào?

Khi CPU gặp `call func`:
1. Push địa chỉ instruction tiếp theo vào stack (return address)
2. Nhảy đến địa chỉ `func`

Khi `ret`:
1. Pop return address từ stack
2. Nhảy về đó

```
Stack trước call:
  [... data ...]  ← rsp

Stack sau call (trong func):
  [return addr]  ← rsp - 8 (push tự động)
  [... data ...]
```

## Floating point

Số float dùng register riêng: **XMM registers** (x86) hoặc **V registers** (ARM64).

```
; LLVM IR: fadd double %a, %b
; x86-64:
addsd xmm0, xmm1   ; add scalar double
```

XMM registers: xmm0–xmm15, mỗi cái 128-bit.
Tham số float truyền qua xmm0, xmm1, ... (không qua rdi, rsi).

## Printf hoạt động thế nào?

VNLang `in("xin chao")` → LLVM `call @printf`:

```llvm
@str = private constant [9 x i8] c"xin chao\00"
; ...
call i32 (i8*, ...) @printf(i8* @str)
```

Ở tầng assembly:
```
lea rdi, [rip + str]   ; rdi = địa chỉ string
call printf            ; gọi printf từ libc
```

`printf` là một hàm C trong **libc** (glibc trên Linux, libSystem trên macOS).
Nó đọc format string, xử lý `%lld`, `%s`... và write ra stdout (fd=1) qua syscall.

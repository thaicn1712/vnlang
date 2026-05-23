# 06 – Biểu diễn Bit/Byte trong VNLang

## Các kiểu cơ bản

### `so` → i64 (64-bit signed integer)

```
Giá trị: 42
Binary:  0000 0000  0000 0000  0000 0000  0000 0000
         0000 0000  0000 0000  0000 0000  0010 1010
Hex:     00 00 00 00 00 00 00 2A
```

**Two's complement** – cách biểu diễn số âm:

```
+5:  0000...0101
-5:  1111...1011   (đảo bit rồi cộng 1)
```

Phép tính: `icmp slt` (signed less than) dùng vì i64 là signed.

```
Tại sao signed? Để hỗ trợ số âm. Phạm vi i64:
  Min: -9,223,372,036,854,775,808  (-2^63)
  Max:  9,223,372,036,854,775,807  (2^63 - 1)
```

### `logic` → i1 (1-bit boolean)

```
dung = 1 = 0000 0001 (trong memory: pad thành 8-bit)
sai  = 0 = 0000 0000
```

`i1` trong LLVM: chỉ có giá trị 0 hoặc 1.
Khi store vào memory, thực tế chiếm ≥ 1 byte (alignment).

### `chu` → i8* (pointer to null-terminated string)

String "xin chao" trong memory:

```
Địa chỉ: 0x1000  0x1001  0x1002  0x1003  ...  0x1008
Giá trị: 'x'     'i'     'n'     ' '     ...   '\0'
Hex:      78      69      6E      20      ...   00
```

- Mỗi ký tự = 1 byte (ASCII)
- Kết thúc bằng null byte `\0` (C convention)
- `i8*` = pointer = địa chỉ 8 bytes (trên 64-bit system)

```
i8* = [48 bits address space | alignment bits]
Ví dụ: 0x00007FFF5FBFF8A0
```

### Float (double) – IEEE 754

VNLang v0.1.0 dùng `double` (64-bit):

```
3.14:
Sign(1) | Exponent(11) | Mantissa(52)
   0    | 10000000000  | 1001000111101011100001010001111010111000010100011111

Hex: 40 09 1E B8 51 EB 85 1F
```

Quy tắc IEEE 754:
```
value = (-1)^sign × 2^(exponent-1023) × (1 + mantissa/2^52)
```

Lý do float không chính xác: `0.1 + 0.2 ≠ 0.3` trong binary:
```
0.1 = 0.0001100110011... (lặp vô hạn trong binary)
```

## Stack layout khi chạy VNLang program

```
# Source:
bien x = 5
bien y = 10
bien z = x + y

# Stack frame của main():
High addr
┌──────────────┐
│ return addr  │  8 bytes (địa chỉ về OS)
├──────────────┤ ← rbp
│ %x = 5       │  8 bytes (i64)   [rbp - 8]
│ %y = 10      │  8 bytes (i64)   [rbp - 16]
│ %z = 15      │  8 bytes (i64)   [rbp - 24]
└──────────────┘ ← rsp
Low addr
```

## Alignment

CPU đọc memory hiệu quả nhất khi địa chỉ align với kích thước:

| Type | Kích thước | Alignment |
|---|---|---|
| i1, i8 | 1 byte | 1 byte |
| i16 | 2 bytes | 2 bytes |
| i32 | 4 bytes | 4 bytes |
| i64, double, i8* | 8 bytes | 8 bytes |

`alloca i64` → LLVM tự đảm bảo 8-byte alignment trên stack.

Ví dụ: nếu stack pointer là 0x1000 và ta alloca i64,
địa chỉ sẽ là 0xFF8 (multiple of 8), không phải 0xFF7.

## Endianness

**Little-endian** (Intel x86, ARM):
Byte thấp nhất ở địa chỉ thấp nhất.

```
Giá trị: 0x0102030405060708 (i64)
Trong memory tại địa chỉ 0x1000:
  0x1000: 08
  0x1001: 07
  0x1002: 06
  0x1003: 05
  0x1004: 04
  0x1005: 03
  0x1006: 02
  0x1007: 01
```

## Ví dụ đầy đủ: `bien x = 42` → bytes trên stack

```
Instruction LLVM IR:
  %x = alloca i64     ; rsp -= 8, x_addr = rsp
  store i64 42, i64* %x

Machine code thực thi:
  sub rsp, 8          ; mở rộng stack
  mov qword [rsp], 42 ; ghi 42 = 0x2A

Memory tại rsp:
  [rsp+0]: 2A   (byte thấp nhất của 42)
  [rsp+1]: 00
  [rsp+2]: 00
  [rsp+3]: 00
  [rsp+4]: 00
  [rsp+5]: 00
  [rsp+6]: 00
  [rsp+7]: 00
```

Khi đọc lại: `load i64, i64* %x` → `movq rax, [rsp]` → rax = 0x000000000000002A = 42.

## String constant trong binary

```
@fmt = private constant [6 x i8] c"%lld\0A\00"
```

`\0A` = 0x0A = newline (`\n`), `\00` = null terminator.

Chuỗi này sống trong **rodata section** của binary (read-only data),
không phải trên stack. Địa chỉ của nó là một constant tại load time.

```
ELF binary sections:
  .text    ← machine code (instructions)
  .rodata  ← string literals, const arrays
  .data    ← global mutable variables
  .bss     ← uninitialized globals (zero-initialized)
  .stack   ← local variables (runtime, không có trong file)
  .heap    ← malloc/free (runtime, không có trong file)
```

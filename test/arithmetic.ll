; ModuleID = 'vnlang'
source_filename = "vnlang"

@fmt = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@fmt.1 = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@fmt.2 = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@fmt.3 = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@fmt.4 = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1

declare i32 @printf(i8*, ...)

define i32 @main() {
entry:
  %a = alloca i64, align 8
  store i64 10, i64* %a, align 4
  %b = alloca i64, align 8
  store i64 3, i64* %b, align 4
  %a1 = load i64, i64* %a, align 4
  %b2 = load i64, i64* %b, align 4
  %add = add i64 %a1, %b2
  %0 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt, i32 0, i32 0), i64 %add)
  %a3 = load i64, i64* %a, align 4
  %b4 = load i64, i64* %b, align 4
  %sub = sub i64 %a3, %b4
  %1 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt.1, i32 0, i32 0), i64 %sub)
  %a5 = load i64, i64* %a, align 4
  %b6 = load i64, i64* %b, align 4
  %mul = mul i64 %a5, %b6
  %2 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt.2, i32 0, i32 0), i64 %mul)
  %a7 = load i64, i64* %a, align 4
  %b8 = load i64, i64* %b, align 4
  %sdiv = sdiv i64 %a7, %b8
  %3 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt.3, i32 0, i32 0), i64 %sdiv)
  %a9 = load i64, i64* %a, align 4
  %b10 = load i64, i64* %b, align 4
  %add11 = add i64 %a9, %b10
  %mul12 = mul i64 %add11, 2
  %result = alloca i64, align 8
  store i64 %mul12, i64* %result, align 4
  %result13 = load i64, i64* %result, align 4
  %4 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt.4, i32 0, i32 0), i64 %result13)
  ret i32 0
}

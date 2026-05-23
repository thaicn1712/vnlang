; ModuleID = 'vnlang'
source_filename = "vnlang"

@str = private unnamed_addr constant [14 x i8] c"square of 7 =\00", align 1
@fmt = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1
@fmt.1 = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@str.2 = private unnamed_addr constant [26 x i8] c"result is greater than 40\00", align 1
@fmt.3 = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1
@str.4 = private unnamed_addr constant [21 x i8] c"result is 40 or less\00", align 1
@fmt.5 = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1

declare i32 @printf(i8*, ...)

define i64 @square(i64 %0) {
entry:
  %x = alloca i64, align 8
  store i64 %0, i64* %x, align 4
  %x1 = load i64, i64* %x, align 4
  %x2 = load i64, i64* %x, align 4
  %mul = mul i64 %x1, %x2
  ret i64 %mul
}

define i32 @main() {
entry:
  %n = alloca i64, align 8
  store i64 7, i64* %n, align 4
  %n1 = load i64, i64* %n, align 4
  %call = call i64 @square(i64 %n1)
  %result = alloca i64, align 8
  store i64 %call, i64* %result, align 4
  %0 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt, i32 0, i32 0), i8* getelementptr inbounds ([14 x i8], [14 x i8]* @str, i32 0, i32 0))
  %result2 = load i64, i64* %result, align 4
  %1 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt.1, i32 0, i32 0), i64 %result2)
  %result3 = load i64, i64* %result, align 4
  %gt = icmp sgt i64 %result3, 40
  br i1 %gt, label %then, label %else

then:                                             ; preds = %entry
  %2 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt.3, i32 0, i32 0), i8* getelementptr inbounds ([26 x i8], [26 x i8]* @str.2, i32 0, i32 0))
  br label %merge

else:                                             ; preds = %entry
  %3 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt.5, i32 0, i32 0), i8* getelementptr inbounds ([21 x i8], [21 x i8]* @str.4, i32 0, i32 0))
  br label %merge

merge:                                            ; preds = %else, %then
  ret i32 0
}

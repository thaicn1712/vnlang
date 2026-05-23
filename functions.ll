; ModuleID = 'vnlang'
source_filename = "vnlang"

@fmt = private unnamed_addr constant [6 x i8] c"%lld\0A\00", align 1
@str = private unnamed_addr constant [19 x i8] c"Result is positive\00", align 1
@fmt.1 = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1
@str.2 = private unnamed_addr constant [23 x i8] c"Result is not positive\00", align 1
@fmt.3 = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1

declare i32 @printf(i8*, ...)

define i64 @add(i64 %0, i64 %1) {
entry:
  %a = alloca i64, align 8
  store i64 %0, i64* %a, align 4
  %b = alloca i64, align 8
  store i64 %1, i64* %b, align 4
  %a1 = load i64, i64* %a, align 4
  %b2 = load i64, i64* %b, align 4
  %add = add i64 %a1, %b2
  ret i64 %add
}

define i1 @is_positive(i64 %0) {
entry:
  %x = alloca i64, align 8
  store i64 %0, i64* %x, align 4
  %x1 = load i64, i64* %x, align 4
  %gt = icmp sgt i64 %x1, 0
  ret i1 %gt
}

define i32 @main() {
entry:
  %x = alloca i64, align 8
  store i64 5, i64* %x, align 4
  %y = alloca i64, align 8
  store i64 8, i64* %y, align 4
  %x1 = load i64, i64* %x, align 4
  %y2 = load i64, i64* %y, align 4
  %call = call i64 @add(i64 %x1, i64 %y2)
  %total = alloca i64, align 8
  store i64 %call, i64* %total, align 4
  %total3 = load i64, i64* %total, align 4
  %0 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @fmt, i32 0, i32 0), i64 %total3)
  %total4 = load i64, i64* %total, align 4
  %call5 = call i1 @is_positive(i64 %total4)
  br i1 %call5, label %then, label %else

then:                                             ; preds = %entry
  %1 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt.1, i32 0, i32 0), i8* getelementptr inbounds ([19 x i8], [19 x i8]* @str, i32 0, i32 0))
  br label %merge

else:                                             ; preds = %entry
  %2 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt.3, i32 0, i32 0), i8* getelementptr inbounds ([23 x i8], [23 x i8]* @str.2, i32 0, i32 0))
  br label %merge

merge:                                            ; preds = %else, %then
  ret i32 0
}

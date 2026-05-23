; ModuleID = 'vnlang'
source_filename = "vnlang"

@str = private unnamed_addr constant [19 x i8] c"Hello from VNLang!\00", align 1
@fmt = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1
@str.1 = private unnamed_addr constant [15 x i8] c"Version: 0.1.0\00", align 1
@fmt.2 = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 1

declare i32 @printf(i8*, ...)

define i32 @main() {
entry:
  %0 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt, i32 0, i32 0), i8* getelementptr inbounds ([19 x i8], [19 x i8]* @str, i32 0, i32 0))
  %1 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @fmt.2, i32 0, i32 0), i8* getelementptr inbounds ([15 x i8], [15 x i8]* @str.1, i32 0, i32 0))
  ret i32 0
}

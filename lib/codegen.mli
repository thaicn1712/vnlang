(** Sinh LLVM IR từ AST.
    Yêu cầu: llvm.14.x (opam). Xem CHANGELOG.md để biết cách migrate lên 15+. *)

val compile : Ast.program -> Llvm.llmodule

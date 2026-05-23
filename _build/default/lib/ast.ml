(** AST types for VNLang v0.1.0 *)

type typ =
  | TSo     (** so    -> i64 in LLVM *)
  | TChu    (** chu   -> i8* in LLVM (string pointer) *)
  | TLogic  (** logic -> i1  in LLVM *)
  | TVoid

type binop =
  | Add | Sub | Mul | Div
  | Eq | Neq | Lt | Gt | Lte | Gte

type expr =
  | IntLit    of int
  | FloatLit  of float
  | BoolLit   of bool
  | StringLit of string
  | Var       of string
  | BinOp     of binop * expr * expr
  | Neg       of expr
  | Call      of string * expr list

type stmt =
  | VarDecl  of string * expr
  | FuncDecl of string * (string * typ) list * typ * stmt list
  | If       of expr * stmt list * stmt list option
  | Return   of expr
  | ExprStmt of expr

type program = stmt list

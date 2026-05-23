type token =
  | Int    of int
  | Float  of float
  | Str    of string
  | Ident  of string
  (* keywords *)
  | Bien | Ham | TraVe | Neu | Khong | InKw
  | SoKw | ChuKw | LogicKw | Dung | Sai
  (* operators *)
  | Plus | Minus | Star | Slash
  | Eq | EqEq | Neq | Lt | Gt | Lte | Gte
  (* delimiters *)
  | LParen | RParen | LBrace | RBrace
  | Colon | Comma
  | EOF

val tokenize : string -> token list
val token_to_string : token -> string

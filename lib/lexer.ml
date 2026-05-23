(** Lexer: splits source text into a token list. O(n) complexity. *)

type token =
  | Int    of int
  | Float  of float
  | Str    of string
  | Ident  of string
  | Bien | Ham | TraVe | Neu | Khong | InKw
  | SoKw | ChuKw | LogicKw | Dung | Sai
  | Plus | Minus | Star | Slash
  | Eq | EqEq | Neq | Lt | Gt | Lte | Gte
  | LParen | RParen | LBrace | RBrace
  | Colon | Comma
  | EOF

let token_to_string = function
  | Int n    -> Printf.sprintf "INT(%d)" n
  | Float f  -> Printf.sprintf "FLOAT(%g)" f
  | Str s    -> Printf.sprintf "STR(%S)" s
  | Ident s  -> Printf.sprintf "IDENT(%s)" s
  | Bien     -> "bien"   | Ham    -> "ham"    | TraVe   -> "tra_ve"
  | Neu      -> "neu"    | Khong  -> "khong"  | InKw    -> "in"
  | SoKw     -> "so"     | ChuKw  -> "chu"    | LogicKw -> "logic"
  | Dung     -> "dung"   | Sai    -> "sai"
  | Plus     -> "+"      | Minus  -> "-"      | Star    -> "*"  | Slash -> "/"
  | Eq       -> "="      | EqEq   -> "=="     | Neq     -> "!="
  | Lt       -> "<"      | Gt     -> ">"      | Lte     -> "<=" | Gte   -> ">="
  | LParen   -> "("      | RParen -> ")"      | LBrace  -> "{" | RBrace -> "}"
  | Colon    -> ":"      | Comma  -> ","      | EOF     -> "EOF"

let keywords = [
  "bien",   Bien;   "ham",   Ham;    "tra_ve", TraVe;
  "neu",    Neu;    "khong", Khong;  "in",     InKw;
  "so",     SoKw;   "chu",   ChuKw;  "logic",  LogicKw;
  "dung",   Dung;   "sai",   Sai;
]

type state = { src : string; mutable pos : int; mutable line : int }

let cur s = if s.pos < String.length s.src then Some s.src.[s.pos] else None

let adv s =
  (match cur s with Some '\n' -> s.line <- s.line + 1 | _ -> ());
  s.pos <- s.pos + 1

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'
let is_alnum c = is_alpha c || is_digit c

let read_number s =
  let start = s.pos in
  let is_float = ref false in
  while (match cur s with Some c when is_digit c || c = '.' -> true | _ -> false) do
    (match cur s with Some '.' -> is_float := true | _ -> ());
    adv s
  done;
  let text = String.sub s.src start (s.pos - start) in
  if !is_float then Float (float_of_string text) else Int (int_of_string text)

let read_ident s =
  let start = s.pos in
  while (match cur s with Some c when is_alnum c -> true | _ -> false) do adv s done;
  let text = String.sub s.src start (s.pos - start) in
  match List.assoc_opt text keywords with
  | Some kw -> kw
  | None    -> Ident text

let read_string s =
  adv s;
  let buf = Buffer.create 32 in
  let rec loop () =
    match cur s with
    | None     -> failwith (Printf.sprintf "line %d: unterminated string" s.line)
    | Some '"' -> adv s
    | Some '\\' ->
      adv s;
      (match cur s with
       | Some 'n'  -> Buffer.add_char buf '\n'; adv s
       | Some 't'  -> Buffer.add_char buf '\t'; adv s
       | Some '"'  -> Buffer.add_char buf '"';  adv s
       | Some '\\' -> Buffer.add_char buf '\\'; adv s
       | Some c    -> Buffer.add_char buf '\\'; Buffer.add_char buf c; adv s
       | None      -> failwith "unexpected EOF in string escape");
      loop ()
    | Some c -> Buffer.add_char buf c; adv s; loop ()
  in
  loop ();
  Str (Buffer.contents buf)

let tokenize src =
  let s = { src; pos = 0; line = 1 } in
  let acc = ref [] in
  let push t = acc := t :: !acc in
  let rec loop () =
    match cur s with
    | None -> push EOF
    | Some ' ' | Some '\t' | Some '\r' | Some '\n' -> adv s; loop ()
    | Some '#' ->
      while (match cur s with Some '\n' | None -> false | _ -> true) do adv s done;
      loop ()
    | Some c ->
      (match c with
       | '+' -> adv s; push Plus
       | '-' -> adv s; push Minus
       | '*' -> adv s; push Star
       | '/' -> adv s; push Slash
       | '(' -> adv s; push LParen
       | ')' -> adv s; push RParen
       | '{' -> adv s; push LBrace
       | '}' -> adv s; push RBrace
       | ':' -> adv s; push Colon
       | ',' -> adv s; push Comma
       | '=' -> adv s; (match cur s with Some '=' -> adv s; push EqEq | _ -> push Eq)
       | '!' -> adv s; (match cur s with
                        | Some '=' -> adv s; push Neq
                        | _ -> failwith (Printf.sprintf "line %d: expected '=' after '!'" s.line))
       | '<' -> adv s; (match cur s with Some '=' -> adv s; push Lte | _ -> push Lt)
       | '>' -> adv s; (match cur s with Some '=' -> adv s; push Gte | _ -> push Gt)
       | '"' -> push (read_string s)
       | c when is_digit c -> push (read_number s)
       | c when is_alpha c -> push (read_ident s)
       | c -> failwith (Printf.sprintf "line %d: unexpected character '%c'" s.line c));
      loop ()
  in
  loop ();
  List.rev !acc

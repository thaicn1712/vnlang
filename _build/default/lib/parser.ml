(** Recursive-descent LL(1) parser. Converts token list -> AST. *)

type state = {
  tokens : Lexer.token array;
  mutable pos : int;
}

let create toks = { tokens = Array.of_list toks; pos = 0 }

let cur s =
  if s.pos < Array.length s.tokens then s.tokens.(s.pos) else Lexer.EOF

let adv s = if s.pos < Array.length s.tokens then s.pos <- s.pos + 1

let expect s tok =
  if cur s = tok then adv s
  else failwith (Printf.sprintf "parse error: expected '%s', got '%s'"
                   (Lexer.token_to_string tok) (Lexer.token_to_string (cur s)))

(* See docs/03-ast-parser.md for the full grammar. *)

let rec parse_program s =
  let stmts = ref [] in
  while cur s <> Lexer.EOF do
    stmts := parse_stmt s :: !stmts
  done;
  List.rev !stmts

and parse_stmt s =
  match cur s with
  | Lexer.Bien  -> parse_var_decl s
  | Lexer.Ham   -> parse_func_decl s
  | Lexer.Neu   -> parse_if s
  | Lexer.TraVe -> parse_return s
  | _           -> parse_expr_stmt s

and parse_var_decl s =
  adv s;
  let name = match cur s with
    | Lexer.Ident n -> adv s; n
    | t -> failwith (Printf.sprintf "parse error: expected identifier after 'bien', got '%s'"
                       (Lexer.token_to_string t))
  in
  expect s Lexer.Eq;
  Ast.VarDecl (name, parse_expr s)

and parse_func_decl s =
  adv s;
  let name = match cur s with
    | Lexer.Ident n -> adv s; n
    | t -> failwith (Printf.sprintf "parse error: expected function name, got '%s'"
                       (Lexer.token_to_string t))
  in
  expect s Lexer.LParen;
  let params = parse_params s in
  expect s Lexer.RParen;
  expect s Lexer.Colon;
  let ret = parse_type s in
  Ast.FuncDecl (name, params, ret, parse_block s)

and parse_params s =
  if cur s = Lexer.RParen then []
  else
    let first = parse_param s in
    let rest  = ref [] in
    while cur s = Lexer.Comma do adv s; rest := parse_param s :: !rest done;
    first :: List.rev !rest

and parse_param s =
  let name = match cur s with
    | Lexer.Ident n -> adv s; n
    | t -> failwith (Printf.sprintf "parse error: expected param name, got '%s'"
                       (Lexer.token_to_string t))
  in
  expect s Lexer.Colon;
  (name, parse_type s)

and parse_type s =
  match cur s with
  | Lexer.SoKw    -> adv s; Ast.TSo
  | Lexer.ChuKw   -> adv s; Ast.TChu
  | Lexer.LogicKw -> adv s; Ast.TLogic
  | t -> failwith (Printf.sprintf "parse error: expected type (so/chu/logic), got '%s'"
                     (Lexer.token_to_string t))

and parse_block s =
  expect s Lexer.LBrace;
  let stmts = ref [] in
  while cur s <> Lexer.RBrace && cur s <> Lexer.EOF do
    stmts := parse_stmt s :: !stmts
  done;
  expect s Lexer.RBrace;
  List.rev !stmts

and parse_if s =
  adv s;
  expect s Lexer.LParen;
  let cond = parse_expr s in
  expect s Lexer.RParen;
  let then_b = parse_block s in
  let else_b =
    if cur s = Lexer.Khong then (adv s; Some (parse_block s)) else None
  in
  Ast.If (cond, then_b, else_b)

and parse_return s =
  adv s; Ast.Return (parse_expr s)

and parse_expr_stmt s =
  Ast.ExprStmt (parse_expr s)

and parse_expr s = parse_comparison s

and parse_comparison s =
  let left = parse_sum s in
  match cur s with
  | Lexer.EqEq -> adv s; Ast.BinOp (Ast.Eq,  left, parse_sum s)
  | Lexer.Neq  -> adv s; Ast.BinOp (Ast.Neq, left, parse_sum s)
  | Lexer.Lt   -> adv s; Ast.BinOp (Ast.Lt,  left, parse_sum s)
  | Lexer.Gt   -> adv s; Ast.BinOp (Ast.Gt,  left, parse_sum s)
  | Lexer.Lte  -> adv s; Ast.BinOp (Ast.Lte, left, parse_sum s)
  | Lexer.Gte  -> adv s; Ast.BinOp (Ast.Gte, left, parse_sum s)
  | _          -> left

and parse_sum s =
  let acc = ref (parse_term s) in
  while cur s = Lexer.Plus || cur s = Lexer.Minus do
    let op = if cur s = Lexer.Plus then (adv s; Ast.Add) else (adv s; Ast.Sub) in
    acc := Ast.BinOp (op, !acc, parse_term s)
  done; !acc

and parse_term s =
  let acc = ref (parse_factor s) in
  while cur s = Lexer.Star || cur s = Lexer.Slash do
    let op = if cur s = Lexer.Star then (adv s; Ast.Mul) else (adv s; Ast.Div) in
    acc := Ast.BinOp (op, !acc, parse_factor s)
  done; !acc

and parse_factor s =
  match cur s with
  | Lexer.Minus -> adv s; Ast.Neg (parse_factor s)
  | _           -> parse_atom s

and parse_args s =
  if cur s = Lexer.RParen then []
  else
    let first = parse_expr s in
    let rest  = ref [] in
    while cur s = Lexer.Comma do adv s; rest := parse_expr s :: !rest done;
    first :: List.rev !rest

and parse_atom s =
  match cur s with
  | Lexer.Int n   -> adv s; Ast.IntLit n
  | Lexer.Float f -> adv s; Ast.FloatLit f
  | Lexer.Str str -> adv s; Ast.StringLit str
  | Lexer.Dung    -> adv s; Ast.BoolLit true
  | Lexer.Sai     -> adv s; Ast.BoolLit false
  | Lexer.LParen  -> adv s; let e = parse_expr s in expect s Lexer.RParen; e
  | Lexer.InKw    ->
    adv s; expect s Lexer.LParen;
    let args = parse_args s in expect s Lexer.RParen;
    Ast.Call ("in", args)
  | Lexer.Ident name ->
    adv s;
    if cur s = Lexer.LParen then begin
      adv s;
      let args = parse_args s in expect s Lexer.RParen;
      Ast.Call (name, args)
    end else Ast.Var name
  | t -> failwith (Printf.sprintf "parse error: unexpected token '%s'"
                     (Lexer.token_to_string t))

let parse tokens = parse_program (create tokens)

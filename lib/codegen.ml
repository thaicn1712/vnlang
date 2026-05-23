(** Codegen: AST -> LLVM IR.
    Target: LLVM 14.x OCaml bindings.
    LLVM 15+ migration notes (marked with (* LLVM 15+: ... *)):
      build_call  -> build_call2 (needs explicit function type)
      build_load  -> build_load2 (needs explicit element type)
      pointer_type elem_ty -> pointer_type ctx (opaque pointer) *)

(* ── Environment ─────────────────────────────────────────────────────── *)

type var_info = {
  alloca : Llvm.llvalue;
  vtyp   : Ast.typ;
}

type env = {
  ctx       : Llvm.llcontext;
  mdl       : Llvm.llmodule;
  builder   : Llvm.llbuilder;
  vars      : (string, var_info) Hashtbl.t;
  funcs     : (string, Llvm.llvalue * Ast.typ list * Ast.typ) Hashtbl.t;
  cur_func  : Llvm.llvalue option;
  printf_fn : Llvm.llvalue;
  printf_ty : Llvm.lltype;
}

(* ── Type helpers ─────────────────────────────────────────────────────── *)

let ll_of_vn env = function
  | Ast.TSo    -> Llvm.i64_type env.ctx
  | Ast.TChu   -> Llvm.pointer_type (Llvm.i8_type env.ctx)
                  (* LLVM 15+: Llvm.pointer_type env.ctx *)
  | Ast.TLogic -> Llvm.i1_type env.ctx
  | Ast.TVoid  -> Llvm.void_type env.ctx

let vn_of_ll env llt =
  if llt = Llvm.i64_type env.ctx    then Ast.TSo
  else if llt = Llvm.double_type env.ctx then Ast.TSo
  else if llt = Llvm.i1_type env.ctx    then Ast.TLogic
  else Ast.TChu

let is_float env v = Llvm.type_of v = Llvm.double_type env.ctx

(* ── Terminator guard ────────────────────────────────────────────────── *)

let terminated env =
  (* insertion_block raises Not_found when LLVM clears the insert point
     after a ret instruction — treat that state as terminated. *)
  try
    match Llvm.block_terminator (Llvm.insertion_block env.builder) with
    | Some _ -> true | None -> false
  with Not_found -> true

let maybe_br env target =
  if not (terminated env) then ignore (Llvm.build_br target env.builder)

(* ── Printf wrapper ──────────────────────────────────────────────────── *)

let call_printf env fmt_str args =
  let fmt = Llvm.build_global_stringptr fmt_str "fmt" env.builder in
  let all = Array.append [| fmt |] args in
  (* LLVM 15+: Llvm.build_call2 env.printf_ty env.printf_fn all "" env.builder *)
  ignore (Llvm.build_call env.printf_fn all "" env.builder)

(* ── Expression codegen ──────────────────────────────────────────────── *)

let rec codegen_expr env = function
  | Ast.IntLit n    -> Llvm.const_int (Llvm.i64_type env.ctx) n
  | Ast.FloatLit f  -> Llvm.const_float (Llvm.double_type env.ctx) f
  | Ast.BoolLit b   -> Llvm.const_int (Llvm.i1_type env.ctx) (if b then 1 else 0)
  | Ast.StringLit s -> Llvm.build_global_stringptr s "str" env.builder

  | Ast.Var name ->
    let info = match Hashtbl.find_opt env.vars name with
      | Some i -> i
      | None   -> failwith (Printf.sprintf "undefined variable '%s'" name)
    in
    (* LLVM 15+: Llvm.build_load2 (ll_of_vn env info.vtyp) info.alloca name env.builder *)
    Llvm.build_load info.alloca name env.builder

  | Ast.BinOp (op, l, r) ->
    let lv = codegen_expr env l and rv = codegen_expr env r in
    let fl = is_float env lv in
    (match op with
     | Ast.Add -> if fl then Llvm.build_fadd lv rv "fadd" env.builder
                  else      Llvm.build_add  lv rv "add"  env.builder
     | Ast.Sub -> if fl then Llvm.build_fsub lv rv "fsub" env.builder
                  else      Llvm.build_sub  lv rv "sub"  env.builder
     | Ast.Mul -> if fl then Llvm.build_fmul lv rv "fmul" env.builder
                  else      Llvm.build_mul  lv rv "mul"  env.builder
     | Ast.Div -> if fl then Llvm.build_fdiv lv rv "fdiv" env.builder
                  else      Llvm.build_sdiv lv rv "sdiv" env.builder
     | Ast.Eq  -> if fl then Llvm.build_fcmp Llvm.Fcmp.Oeq lv rv "feq"  env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Eq  lv rv "eq"   env.builder
     | Ast.Neq -> if fl then Llvm.build_fcmp Llvm.Fcmp.One lv rv "fneq" env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Ne  lv rv "neq"  env.builder
     | Ast.Lt  -> if fl then Llvm.build_fcmp Llvm.Fcmp.Olt lv rv "flt"  env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Slt lv rv "lt"   env.builder
     | Ast.Gt  -> if fl then Llvm.build_fcmp Llvm.Fcmp.Ogt lv rv "fgt"  env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Sgt lv rv "gt"   env.builder
     | Ast.Lte -> if fl then Llvm.build_fcmp Llvm.Fcmp.Ole lv rv "flte" env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Sle lv rv "lte"  env.builder
     | Ast.Gte -> if fl then Llvm.build_fcmp Llvm.Fcmp.Oge lv rv "fgte" env.builder
                  else      Llvm.build_icmp Llvm.Icmp.Sge lv rv "gte"  env.builder)

  | Ast.Neg e ->
    let v = codegen_expr env e in
    if is_float env v then Llvm.build_fneg v "fneg" env.builder
    else                   Llvm.build_neg  v "neg"  env.builder

  | Ast.Call ("in", args) ->
    codegen_print env args;
    Llvm.const_int (Llvm.i64_type env.ctx) 0

  | Ast.Call (name, args) ->
    let (fn, _, ret_ty) = match Hashtbl.find_opt env.funcs name with
      | Some x -> x
      | None   -> failwith (Printf.sprintf "undefined function '%s'" name)
    in
    let arg_vals = Array.of_list (List.map (codegen_expr env) args) in
    let result_name = if ret_ty = Ast.TVoid then "" else "call" in
    (* LLVM 15+: build_call2 with explicit function type *)
    Llvm.build_call fn arg_vals result_name env.builder

(* ── Print builtin ───────────────────────────────────────────────────── *)

and codegen_print env args =
  let i64_t = Llvm.i64_type env.ctx in
  let f64_t = Llvm.double_type env.ctx in
  let i1_t  = Llvm.i1_type env.ctx in
  List.iter (fun arg ->
    let v  = codegen_expr env arg in
    let ty = Llvm.type_of v in
    if      ty = i64_t then call_printf env "%lld\n" [| v |]
    else if ty = f64_t then call_printf env "%f\n"   [| v |]
    else if ty = i1_t  then
      let ext = Llvm.build_zext v i64_t "bool_ext" env.builder in
      call_printf env "%lld\n" [| ext |]
    else call_printf env "%s\n" [| v |]   (* string pointer *)
  ) args

(* ── Statement codegen ───────────────────────────────────────────────── *)

and codegen_stmt env stmt =
  (* Only skip dead code when inside a function; at top level the builder
     has no insertion block yet, which must not be mistaken for "terminated". *)
  if (match env.cur_func with Some _ -> terminated env | None -> false) then ()
  else match stmt with

  | Ast.VarDecl (name, expr) ->
    let v    = codegen_expr env expr in
    let llt  = Llvm.type_of v in
    let vtyp = vn_of_ll env llt in
    let alloca = Llvm.build_alloca llt name env.builder in
    ignore (Llvm.build_store v alloca env.builder);
    Hashtbl.replace env.vars name { alloca; vtyp }

  | Ast.FuncDecl (name, params, ret_ty, body) ->
    let param_llt = Array.of_list (List.map (fun (_, t) -> ll_of_vn env t) params) in
    let fn_ty  = Llvm.function_type (ll_of_vn env ret_ty) param_llt in
    let fn_val = Llvm.define_function name fn_ty env.mdl in
    Llvm.position_at_end (Llvm.entry_block fn_val) env.builder;

    let fn_vars = Hashtbl.create 8 in
    List.iteri (fun i (pname, pty) ->
      let alloca = Llvm.build_alloca (ll_of_vn env pty) pname env.builder in
      ignore (Llvm.build_store (Llvm.param fn_val i) alloca env.builder);
      Hashtbl.replace fn_vars pname { alloca; vtyp = pty }
    ) params;

    let fn_env = { env with vars = fn_vars; cur_func = Some fn_val } in
    List.iter (codegen_stmt fn_env) body;

    if not (terminated fn_env) then
      if ret_ty = Ast.TVoid
      then ignore (Llvm.build_ret_void env.builder)
      else ignore (Llvm.build_ret (Llvm.const_int (ll_of_vn env ret_ty) 0) env.builder);

    Hashtbl.replace env.funcs name (fn_val, List.map snd params, ret_ty)

  | Ast.If (cond, then_body, else_body) ->
    let cond_v = codegen_expr env cond in
    let cond_i1 =
      if Llvm.type_of cond_v = Llvm.i1_type env.ctx then cond_v
      else Llvm.build_icmp Llvm.Icmp.Ne cond_v
             (Llvm.const_int (Llvm.i64_type env.ctx) 0) "cond" env.builder
    in
    let fn = match env.cur_func with Some f -> f | None -> failwith "if outside function" in
    let then_bb  = Llvm.append_block env.ctx "then"  fn in
    let else_bb  = Llvm.append_block env.ctx "else"  fn in
    let merge_bb = Llvm.append_block env.ctx "merge" fn in
    ignore (Llvm.build_cond_br cond_i1 then_bb else_bb env.builder);

    Llvm.position_at_end then_bb env.builder;
    List.iter (codegen_stmt env) then_body;
    maybe_br env merge_bb;

    Llvm.position_at_end else_bb env.builder;
    (match else_body with Some ss -> List.iter (codegen_stmt env) ss | None -> ());
    maybe_br env merge_bb;

    Llvm.position_at_end merge_bb env.builder

  | Ast.Return expr ->
    ignore (Llvm.build_ret (codegen_expr env expr) env.builder)

  | Ast.ExprStmt expr ->
    ignore (codegen_expr env expr)

(* ── Entry point ──────────────────────────────────────────────────────── *)

let compile stmts =
  let ctx    = Llvm.create_context () in
  let mdl    = Llvm.create_module ctx "vnlang" in
  let builder = Llvm.builder ctx in
  let vars   = Hashtbl.create 16 in
  let funcs  = Hashtbl.create 16 in

  let i32_t     = Llvm.i32_type ctx in
  let i8_ptr_t  = Llvm.pointer_type (Llvm.i8_type ctx) in
  let printf_ty = Llvm.var_arg_function_type i32_t [| i8_ptr_t |] in
  let printf_fn = Llvm.declare_function "printf" printf_ty mdl in

  let env = { ctx; mdl; builder; vars; funcs;
              cur_func = None; printf_fn; printf_ty } in

  (* Pass 1: generate all user-defined functions *)
  List.iter (function Ast.FuncDecl _ as s -> codegen_stmt env s | _ -> ()) stmts;

  (* Pass 2: wrap top-level statements into main() *)
  let main_ty = Llvm.function_type i32_t [||] in
  let main_fn = Llvm.define_function "main" main_ty mdl in
  Llvm.position_at_end (Llvm.entry_block main_fn) builder;
  let main_env = { env with cur_func = Some main_fn } in
  List.iter (function Ast.FuncDecl _ -> () | s -> codegen_stmt main_env s) stmts;

  if not (terminated main_env) then
    ignore (Llvm.build_ret (Llvm.const_int i32_t 0) builder);

  mdl

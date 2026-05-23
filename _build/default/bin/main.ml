(** VNLang compiler entry point.
    Usage: vnlang <file.vn> [-o output.ll] *)

let read_file path =
  let ic = open_in path in
  let n  = in_channel_length ic in
  let s  = Bytes.create n in
  really_input ic s 0 n;
  close_in ic;
  Bytes.to_string s

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.eprintf "VNLang v0.1.0\n";
    Printf.eprintf "Usage: vnlang <file.vn> [-o output.ll]\n";
    exit 1
  end;

  let src_file = Sys.argv.(1) in
  let out_file =
    if Array.length Sys.argv >= 4 && Sys.argv.(2) = "-o"
    then Sys.argv.(3)
    else Filename.basename (Filename.remove_extension src_file) ^ ".ll"
  in

  let source = try read_file src_file
    with Sys_error msg -> Printf.eprintf "Error reading file: %s\n" msg; exit 1
  in

  let tokens = try Vnlang_lib.Lexer.tokenize source
    with Failure msg -> Printf.eprintf "Lexer error: %s\n" msg; exit 1
  in

  let ast = try Vnlang_lib.Parser.parse tokens
    with Failure msg -> Printf.eprintf "Parser error: %s\n" msg; exit 1
  in

  let mdl = try Vnlang_lib.Codegen.compile ast
    with Failure msg -> Printf.eprintf "Codegen error: %s\n" msg; exit 1
  in

  Llvm.print_module out_file mdl;
  Printf.printf "Generated: %s\n" out_file;
  Printf.printf "Run with:  lli %s\n" out_file;
  Printf.printf "Compile:   llc %s -o out.s && gcc out.s -o program\n" out_file

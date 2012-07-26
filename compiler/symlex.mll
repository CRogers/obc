(*
 * symlex.mll
 * 
 * This file is part of the Oxford Oberon-2 compiler
 * Copyright (c) 2006 J. M. Spivey
 * All rights reserved
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $Id: symlex.mll 792 2008-12-25 23:27:36Z mike $
 *)

{
open Symparse
open Dict
open Symtab
open Print
open Lexing

let rcsid = "$Id: symlex.mll 792 2008-12-25 23:27:36Z mike $"

let kwtab = Util.make_hash 64
  ([("ARRAY", ARRAY); ("CONST", CONST); ("PARAM", PARAM);
    ("DEF", DEF); ("END", END); ("FIELD", FIELD); ("TARGET", TARGET); 
    ("FLEX", FLEX); ("INTCONST", BASICTYPE numtype); ("METH", METH); 
    ("METHOD", METHOD); ("POINTER", POINTER); ("PROC", PROC);
    ("SYMFILE", SYMFILE); ("PROCEDURE", PROCEDURE); ("RECORD", RECORD); 
    ("STRING", STRING); ("TYPE", TYPE); ("GLOBAL", GLOBAL); ("ANON", ANON);
    ("CPARAM", CPARAM); ("VPARAM", VPARAM); ("ENUM", ENUM);
    ("LOCAL", LOCAL); ("ABSREC", ABSREC); ("ABSMETH", ABSMETH)]
  @ List.map (function t -> (extern t.t_name, BASICTYPE t)) basic_types)

let lookup s =
  try Hashtbl.find kwtab s with
    Not_found -> failwith ("keyword " ^ s)

let line = ref 1
}

rule token = parse
    ['A'-'Z']+		{ lookup (lexeme lexbuf) }
  | '#'['A'-'Z''a'-'z''0'-'9''%''.']+	
			{ let s = lexeme lexbuf in
			  TAG (String.sub s 1 (String.length s - 1)) }
  | '-'?['0'-'9']+	{ NUM (lexeme lexbuf) }
  | '-'?['0'-'9']+'.'['0'-'9']*('e'['+''-']?['0'-'9']+)?
			{ FLO (lexeme lexbuf) }
  | "0x"['0'-'9''a'-'f']+ { HEX (lexeme lexbuf) }
  | "["			{ BRA }
  | "]"			{ KET }
  | ";"			{ SEMI }
  | "-"			{ MARK ReadOnly }
  | "*"			{ MARK Visible }
  | "!"			{ PLING }
  | "?"			{ QUERY }
  | "!!"|" "		{ token lexbuf } 
  | "\n"		{ incr line; token lexbuf }
  | _			{ failwith (sprintf "symlex $" 
			    [fNum (lexeme_start lexbuf)]) }

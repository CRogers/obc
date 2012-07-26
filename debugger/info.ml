(*
 * info.ml
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
 * $Id: info.ml 1675 2011-03-01 20:00:48Z mike $
 *)

open Print
open Symtab
open Dict
open Mach

let rcsid = "$Id: info.ml 1675 2011-03-01 20:00:48Z mike $"

let modules = Hashtbl.create 20
let debug_defs = Hashtbl.create 100

let put_debug d =
  if d.d_lab <> nosym then
    Hashtbl.add debug_defs d.d_lab d

let get_debug x =
  Hashtbl.find debug_defs x

let init =
  Dict.debugger := put_debug;
  let p = { p_kind = Procedure; p_pcount = 0; 
		p_fparams = []; p_result = voidtype } in
  put_debug
    { d_tag = intern "MAIN"; d_module = intern "%Main"; d_kind = ProcDef;
      d_type = new_type 0 (ProcType p, addr_rep, []); d_export = Private; 
      d_loc = Error.no_loc; d_line = 0; d_used = true; d_lab = "MAIN"; 
      d_level = 0; d_offset = 0; d_param = 0; d_env = init_env ();
      d_comment = None; d_map = [] }

let import m objchk =
  try 
    let f = Util.search_path (extern m ^ ".k") !Config.libpath in
    let (env, chksum, _) = Symfile.import f in
    if chksum <> objchk then
      fprintf stderr "? Symbol file for $ has wrong checksum\n" [fId m];
    Hashtbl.add modules m env
  with Not_found ->
    fprintf stderr "? Couldn't find symbol file for $\n" [fId m]

let get_module m = Hashtbl.find modules m


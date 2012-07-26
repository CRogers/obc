(*
 * igen.ml
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
 * $Id: igen.ml 1689 2011-06-17 18:28:43Z mike $
 *)

open Symtab
open Dict
open Tree
open Mach
open Icode
open Eval
open Error
open Print

let rcsid = "$Id: igen.ml 1689 2011-06-17 18:28:43Z mike $"

(* Code output *)

let code_line = ref 0
let line_pending = ref false

(* set_loc -- note line number *)
let set_loc p =
  if p <> no_loc then begin
    let n = line_num p in
    if n <> !code_line then begin
      code_line := n;
      line_pending := true
    end
  end

(* gen -- generate instruction with possible line number *)
let gen i =
  if !line_pending then begin
    Peepopt.gen (LINE !code_line);
    line_pending := false
  end;
  Stack.simulate i; Peepopt.gen i;
  if !Config.debug > 0 then printf "!& $ ($)\n" [fInst i; Stack.fStack]


(* gen_lab -- place a label *)
let gen_lab l = Peepopt.gen (LABEL l)

(* put -- generate a directive *)
let put fmt args = printf "$\n" [fMeta fmt args]

let put_int n = put "WORD $" [fNum n]
let put_sym s = put "WORD $" [fSym s]

let dup n () = gen (DUP n)

let intval n = IntVal (integer n)


(* Pointer maps *)

let maps = ref []

let rec make_bitmap m = 
  let rec bitmap m =
    List.fold_left Int32.logor Int32.zero (List.map item m)
  and item =
    function
	GC_Offset o ->
	  if o < 0 || o >= 4*31 then raise Not_found;
	  Int32.shift_left Int32.one (o/4)
      | GC_Repeat (base, count, stride, m) ->
	  if base < 0 || base + count * stride >= 4*32 then raise Not_found;
	  let b = bitmap m in
	  List.fold_left Int32.logor Int32.zero 
	    (List.map (fun i -> Int32.shift_left b ((base + i * stride) / 4))
	      (Util.range 0 (count-1)))
      | GC_Block (base, count) ->
	  item (GC_Repeat (base, count, 4, [GC_Offset 0]))
      | GC_Flex (_, _, _, _) ->
	  raise Not_found in
  integer_of_int32 (Int32.logor (Int32.shift_left (bitmap m) 1) Int32.one)

let hex_bitmap bm = sprintf "$" [fHexInteger bm]

let make_map lab m =
  if m = [] then "0" else
    try hex_bitmap (make_bitmap m) with
      Not_found ->
        maps := (lab, m) :: !maps; lab

let map_name x = sprintf "$.%map" [fSym x]

let frame_map d =
  make_map (map_name d.d_lab) (shift frame_shift d.d_map)

let type_map t =
  make_map (map_name t.t_desc) t.t_map

let push_map t =
  if t.t_map = [] then
    gen (CONST (integer 0))
  else if t.t_map = [GC_Offset 0] then
    (* A pointer type *)
    gen (CONST (integer 3))
  else begin
    try gen (CONSTx (make_bitmap t.t_map)) with
      Not_found ->
	if t.t_desc <> nosym then
	  gen (GLOBAL (map_name t.t_desc))
	else
	  gen (GLOBAL (make_map (genlab ()) t.t_map))
  end

let gen_stackmap n =
  let m = Stack.make_map n in
  if m <> [] then 
    gen (STKMAP (make_map (genlab ()) (shift (n*word_size) m)))

let rec put_map m = 
  try 
    (* Don't use a bitmap for a single item *)
    if (match m with [GC_Offset o] -> true | _ -> false) then raise Not_found;
    let bm = make_bitmap m in 
    put_sym "GC_MAP"; put_sym (hex_bitmap bm)
  with Not_found ->
    List.iter put_item m

and put_item =
  function
      GC_Offset o -> 
	put_int o
    | GC_Repeat (base, count, stride, m) ->
	put_sym "GC_REPEAT";
	put_int base;
	put_int count;
	put_int stride;
	put_map m;
	put_sym "GC_END"
    | GC_Block (base, count) ->
	put_sym "GC_BLOCK";
	put_int base;
	put_int count
    | GC_Flex (offset, ndim, stride, m) ->
	put_sym "GC_FLEX";
	put_int offset;
	put_int ndim;
	put_int stride;
	put_map m;
	put_sym "GC_END"

let put_maps () =
  if !maps <> [] then begin
    put "! Pointer maps" [];
    List.iter (function (lab, m) -> 
	put "DEFINE $" [fSym lab]; put_map m; put_sym "GC_END"; put "" []) 
      (List.rev !maps)
  end


(* Code generation *)

let level = ref 0			(* nesting level of current proc *)

(* size_of -- calculate size of expression in bytes *)
let size_of e = e.e_type.t_rep.m_size

(* count_of -- calculate size of type in words for parameter *)
let count_of t = (t.t_rep.m_size + word_size - 1) / word_size

let roundup n = (n+3)/4*4

(* is_const -- test if expression is a constant *)
let is_const e = 
  match e.e_guts with (Const _ | Nil) -> true | _ -> false

(* value_of -- get value of constant *)
let value_of e =
  match e.e_guts with
      Const (v, t) -> v
    | _ -> failwith "value_of"

(* op_kind -- machine type for operation *)
let op_kind t = 
  let k = kind_of t in
  match k with 
      FloatT | DoubleT | LongT | BoolT | VoidT -> k 
    | _ -> IntT

(* mem_kind -- machine type for load or store *)
let mem_kind t =
  let k = kind_of t in
  match k with
      BoolT | ByteT -> CharT
    | PtrT | SetT -> IntT
    | _ -> k

(* gen_local -- generate instructions to follow static chain *)
let gen_local l o =
  if l = !level then
    gen (LOCAL o)
  else begin
    gen (LOCAL stat_link);
    gen (LOAD IntT);
    for i = !level-2 downto l do 
      gen (CONST (integer stat_link));
      gen (BINOP (PtrT, PlusA));
      gen (LOAD IntT)
    done;
    gen (CONST (integer o));
    gen (BINOP (PtrT, PlusA))
  end

(* gen_typematch -- generate code to compare record type *)
let gen_typematch t =
  (* Expects the location of the descriptor address on the stack. *)
  let r = get_record t in
  gen (LOAD IntT);
  gen (GLOBAL t.t_desc);
  gen (TYPETEST r.r_depth)

(* gen_conv -- generate code for type conversion *)
let gen_conv t1 t2 =
  let rec convert k1 k2 =
    if k1 <> k2 then begin
      match k1, k2 with
	(* Treat short via integer *)
	  ShortT, _ -> convert IntT k2
	| _, ShortT -> convert k1 IntT; gen (CONV (IntT, ShortT))

	(* Convert from long to float via double *)
	| LongT, FloatT ->
	    gen (CONV (LongT, DoubleT)); gen (CONV (DoubleT, FloatT))

	(* Otherwise convert directly *)
	| (IntT, (LongT | FloatT | DoubleT)) |
	  (LongT, (IntT | DoubleT)) |
	  (FloatT, DoubleT) | (DoubleT, FloatT) -> 
	    gen (CONV (k1, k2))

	| _, _ -> failwith "convert" 
    end in

  match t1.t_guts, t2.t_guts with
      BasicType k1, BasicType k2 -> 
	convert k1 k2
    | _, _ -> failwith "gen_conv"

let mark_type t =
  if is_pointer t then Stack.mark ()

let load_addr () = 
  gen (LOAD IntT); Stack.mark ()

let gen_call pcount rtype =
  gen_stackmap pcount;
  gen (CALL (pcount, op_kind rtype));
  mark_type rtype

let call_proc lab pcount rtype =
  gen (GLOBAL lab); gen_call pcount rtype

(* safe -- test if an expression has no side effects or runtime errors *)
let rec safe e =
  match e.e_guts with
      Deref _ | Sub (_, _) -> false
    | Select (e1, x) -> safe e1
    | FuncCall (_, _) | MethodCall (_, _, _) -> false
    | Monop (w, e1) -> safe e1
    | Binop ((Div|Mod|Over), e1, e2) -> false
    | Binop (w, e1, e2) -> safe e1 && safe e2
    | IfExpr (e1, e2, e3) -> safe e1 && safe e2 && safe e3
    | Set els -> 
	let safe_el = 
	  function 
	      Single e1 -> safe e 
	    | Range (e1, e2) -> safe e1 && safe e2 in
	List.for_all safe_el els
    | Cast (_, _) -> false
    | TypeTest (_, _) -> false
    | _ -> true

(* conditional -- test if an expression requires jumping code *)
let rec conditional e =
  match e.e_guts with
    | Monop (Not, e1) -> conditional e1
    | Binop ((And|Or), e1, e2) -> 
	not (safe e2) || conditional e1 || conditional e2
    | _ -> false

(* null_check -- check value of expression is not null *)
let null_check e =
  match e.e_guts with
      Cast (e1, t) -> ()
    | _ -> gen (CHECK (NullPtr, !code_line))

(* gen_const -- generate code to push a constant *)
let gen_const k v =
  match k with
      NumT | ShortT | IntT | CharT | BoolT -> 
	gen (CONST (int_value v))
    | FloatT | DoubleT | LongT -> gen (TCONST (k, v))
    | _ -> failwith (sprintf "gen_const $" [fType1 k])

(* gen_addr -- generate code to push the address of a variable *)
let rec gen_addr v = 
  match v.e_guts with
      Name x ->
	set_loc x.x_loc;
	let d = get_def x in
	begin match d.d_kind with
	    VarDef ->
	      if d.d_level = 0 then
	        gen (GLOBAL d.d_lab)
	      else
                gen_local d.d_level d.d_offset
	  | ParamDef ->
	      gen_local d.d_level d.d_offset;
	      if is_flex d.d_type then load_addr ()
	  | CParamDef ->
	      gen_local d.d_level d.d_offset;
	      if not (scalar d.d_type) then load_addr ()
          | VParamDef ->
	      gen_local d.d_level d.d_offset;
	      load_addr ()
	  | ProcDef ->
	      (* This is needed when a proc is passed as a parameter
		 of type ARRAY OF SYSTEM.BYTE *)
	      gen (GLOBAL d.d_lab)
          | _ -> failwith "gen_addr"
	end

    | Deref p ->
	gen_expr p;
	if !Config.boundchk then null_check p

    | Sub (_, _) ->
	let e0 = sub_base v in
	let es = subscripts v in
	gen_addr e0;
	gen_offset e0 es;
	gen (BINOP (PtrT, PlusA))

    | Select (r, x) ->
	set_loc x.x_loc;
	let d = get_def x in
        gen_addr r;
        gen (CONST (integer d.d_offset));
        gen (BINOP (PtrT, PlusA))

    | String (lab, n) ->
	gen (GLOBAL lab)

    | Cast (e1, tn) ->
	let d = get_def tn in
	if not (is_record d.d_type) then failwith "addr of cast";
	begin match e1.e_guts with
	    Name x ->
	      let dx = get_def x in
              if dx.d_kind <> VParamDef then failwith "addr of cast 3";
              if !Config.boundchk then begin
	        let lab1 = label () in
	        gen_local dx.d_level (dx.d_offset + word_size);
	        gen_typematch d.d_type;
		gen (JUMPB (true, lab1));
	        gen (ERROR ("E_CAST", !code_line));
	        gen_lab lab1
	      end;
	      gen_local dx.d_level dx.d_offset;
	      load_addr ()
	  | _ -> failwith "addr of cast 2"
	end

    | _ -> failwith "gen_addr"

(* gen_bound -- generate code to push k'th bound of array *)
and gen_bound k e0 addr_fun =
  (* addr_fun () generates code to push the address of e0 without
     duplicating side effects. What a mess! *)
  let rec bound i t1 =
    match t1.t_guts with
	ArrayType (n, t2) -> 
	  if i < k then bound (i+1) t2
	  else gen (CONST (integer n))
      | FlexType t2 ->
	  if i < k then 
	    bound (i+1) t2
	  else begin
	    match e0.e_guts with
		Name x ->
		  (* An open array parameter *)
		  let d = get_def x in
		  gen_local d.d_level (d.d_offset + k * word_size);
		  gen (LOAD IntT)
	      | Deref p ->
		  (* Get descriptor address *)
		  addr_fun ();
		  gen (CONST (integer (-word_size)));
		  gen (BINOP (PtrT, PlusA));
		  load_addr ();

		  (* Fetch k'th dimension *)
		  gen (CONST (integer (bound_offset + (k-1) * word_size)));
		  gen (BINOP (PtrT, PlusA));
		  gen (LOAD IntT)
	      | _ -> failwith "gen_bound 2"
	  end
      | _ -> failwith "gen_bound" in
  bound 1 e0.e_type

and gen_offset e0 us =
  let rec loop i ys t =
    match ys with
	[] -> 
	  if not (is_flex t) then begin
	    gen (CONST (integer t.t_rep.m_size));
	    gen (BINOP (IntT, Times))
	  end
	  else begin
	    gen_bound i e0 (dup 1);
	    gen (BINOP (IntT, Times));
	    loop (i+1) [] (base_type t)
	  end
      | x::xs ->
	  gen_bound i e0 (dup 1);
	  gen (BINOP (IntT, Times));
	  gen_expr x;
	  if !Config.boundchk then begin
	    gen_bound i e0 (dup 2);
	    gen (BOUND !code_line)
	  end;
	  gen (BINOP (IntT, Plus));
	  loop (i+1) xs (base_type t) in
  match us with
      [] -> gen (CONST (integer 0))
    | x::xs ->
	gen_expr x;
	if !Config.boundchk then begin
          gen_bound 1 e0 (dup 1);
          gen (BOUND !code_line)
        end;
	loop 2 xs (base_type e0.e_type)

(* gen_expr -- generate code to push the value of an expression *)
and gen_expr e = 
  if conditional e then
    gen_condval true e
  else begin
    match e.e_guts with
	Const (v, t) -> gen_const (op_kind t) v

      | Name x ->
	  let d = get_def x in
	  begin match d.d_kind with
	      ProcDef ->
		gen (GLOBAL d.d_lab)
	    | _ -> 
		gen_addr e; 
		gen (LOAD (mem_kind e.e_type));
		mark_type e.e_type
	  end

      | Sub _ | Select _ ->
	  gen_addr e;
	  gen (LOAD (mem_kind e.e_type));
	  mark_type e.e_type

      | Monop (w, e1) ->
	  gen_expr e1;
	  if w <> Uplus then
	    gen (MONOP (op_kind e.e_type, w))

      | Binop ((Eq | Neq | Lt | Leq | Gt | Geq) as w, e1, e2) ->
	  let set_leq e1' e2' =
	    gen_expr e1'; gen_expr e2'; 
	    gen (MONOP (IntT, BitNot));
	    gen (BINOP (IntT, BitAnd));
	    gen (CONST (integer 0));
	    gen (BINOP (IntT, Eq)) in

	  if is_string e1.e_type then begin
	    gen_flexarg strtype e2;
	    gen_flexarg strtype e1;
	    call_proc "COMPARE" 4 boolean;
	    gen (CONST (integer 0));
	    gen (BINOP (IntT, w))
	  end
	  else if w = Leq && same_types e1.e_type settype then
	    set_leq e1 e2
	  else if w = Geq && same_types e1.e_type settype then
	    set_leq e2 e1
	  else begin
	    let k = op_kind e1.e_type in
	    if is_const e1 && not (is_const e2) then begin
	      gen_expr e2; gen_expr e1; gen (BINOP (k, commute w))
	    end
	    else begin
	      gen_expr e1; gen_expr e2; gen (BINOP (k, w))
	    end
	  end

      | Binop ((Div | Mod) as w, e1, e2) ->
	  let t = op_kind e.e_type in
	  gen_expr e1; gen_expr e2;
	  if !Config.boundchk then gen (CHECK (DivZero t, !code_line));
	  gen (BINOP (t, w))

      | Binop (Over, e1, e2) ->
	  let t = op_kind e.e_type in
	  gen_expr e1; gen_expr e2;
	  if !Config.boundchk then gen (CHECK (DivZero t, !code_line));
	  gen (BINOP (t, Div))

      | Binop (In, e1, e2) ->
	  gen_expr e1;
	  if !Config.boundchk then begin
	    gen (CONST (integer set_size));
	    gen (BOUND !code_line)
	  end;
	  gen (MONOP (IntT, Bit));
	  gen_expr e2;
	  gen (BINOP (IntT, BitAnd));
	  gen (CONST (integer 0));
	  gen (BINOP (IntT, Neq))

      | Binop (w, e1, e2) ->
	  let gen_it w' e1' e2' =
	    gen_expr e1'; gen_expr e2'; 
	    gen (BINOP (op_kind e.e_type, w')) in
	  if is_const e1 && not (is_const e2) then
	    try let w' = commute w in gen_it w' e2 e1 with 
	      Not_found -> gen_it w e1 e2
	  else
	    gen_it w e1 e2

      | IfExpr (e1, e2, e3) ->
	  let lab1 = label () and lab2 = label () in
	  gen_cond false lab1 e1;
	  gen_expr e2;
	  gen (JUMP lab2);
	  gen (LABEL lab1);
	  gen_expr e3;
	  gen (LABEL lab2)

      | Nil ->
	  gen (CONST (integer 0))

      | Convert e1 ->
	  gen_expr e1;
	  gen_conv e1.e_type e.e_type

      | FuncCall (p, args) -> 
	  gen_proccall p args

      | MethodCall (x, m, args) ->
	  gen_message x m args

      | Cast (e1, tn) ->
	  let d = get_def tn in
	  if not (is_pointer d.d_type) then failwith "val of cast";
	  gen_expr e1;
	  if !Config.boundchk then begin
	    let lab1 = label () in
	    gen (DUP 0);
	    null_check e1;
	    gen (CONST (integer (-word_size)));
	    gen (BINOP (PtrT, PlusA));
	    gen_typematch (base_type d.d_type);
	    gen (JUMPB (true, lab1));
	    gen (ERROR ("E_CAST", !code_line));
	    gen_lab lab1
	  end

      | TypeTest (e1, tn) ->
	  gen_typetest e1 tn

      | Set els ->
	  if els = [] then
	    gen (CONST (integer 0))
	  else begin
	    gen_element (List.hd els);
	    List.iter 
	      (function el -> gen_element el; gen (BINOP (IntT, BitOr)))
	      (List.tl els)
	  end

      | _ -> expr_fail "gen_expr" e
  end

(* gen_proccall -- generate code to call a procedure *)
and gen_proccall f args =
  match f.e_type.t_guts with
      ProcType p ->
	List.iter2 gen_arg (List.rev p.p_fparams) (List.rev args);
	gen_funarg LINK f;
	if !Config.boundchk then gen (CHECK (NullPtr, !code_line));
	gen_call p.p_pcount p.p_result

    | BuiltinType b ->
	gen_builtin b args

    | _ -> failwith "gen_proccall"

(* gen_message -- generate code for a method call *)
and gen_message r m args =
  let d = get_def m in
  let p = get_proc d.d_type in
  List.iter2 gen_arg (List.rev (List.tl p.p_fparams)) (List.rev args);
  let rcvr = List.hd p.p_fparams in
  begin
    match rcvr.d_kind with
	VParamDef ->
	  gen_arg rcvr r;			(* addr+desc *)
	  gen (DUP 1)				(* desc *)
      | (ParamDef | CParamDef) ->
	  gen_addr r;				(* addr *)
	  gen (DUP 0);
	  gen (CONST (integer (-word_size)));
	  gen (BINOP (PtrT, PlusA));
	  gen (LOAD IntT)			(* desc *)
      | _ -> failwith "method receiver" 
  end;
  gen (CONST (integer (method_offset + word_size * d.d_offset)));
  gen (BINOP (PtrT, PlusA));
  gen (LOAD IntT);
  gen_call p.p_pcount p.p_result

(*
This table shows how the three kinds of parameters are passed and how
they are treated in the procedure preamble.  Non-scalar value
parameters are passed by address, then copied in the preamble using
the FIXCOPY and FLEXCOPY instructions.

Const parameters are a language extension, implemented here for a long time,
but made official by Wirth in Oberon-07: they are equivalent to
value parameters, except that no copy is made of non-scalar
parameters, and they are not assignable in the procedure body.  The
programmer must ensure that they are not affected by aliasing.

+----------+--------+---------+-------------+---------------+-----------+
|          | SCALAR | ARRAY   | RECORD      | FLEX          | PROC      |
+----------+--------+---------+-------------+---------------+-----------+
| VALUE    | value  | addr    | addr        | addr+bound    | code+stat |
| (Param)  |        | FIXCOPY | FIXCOPY     | FLEXCOPY *    |           |
+----------+--------+---------+-------------+---------------+-----------+
| CONST    | value  | addr *  | addr *      | addr+bound *  | code+stat |
| (CParam) |        |         |             |               |           |
+----------+--------+---------+-------------+---------------+-----------+
| VAR      | addr * | addr *  | addr+desc * | addr+bound *  | addr *    |
| (VParam) |        |         |             |               |           |
+----------+--------+---------+-------------+---------------+-----------+

If the parameter is copied with FIXCOPY, then its definition contains
the offset of the copy.  With FLEXCOPY, the parameter definition still
points to the argument word, but that word is modified at runtime to
contain the address of the alloca'd space.  So the table cells marked
with * are the ones where gen_addr must generate a (LOAD IntT) 
instruction.  
*)

(* gen_arg -- generate code to push a procedure argument *)
and gen_arg f a = 
  if is_proc f.d_type then begin
    match f.d_kind with
	(ParamDef | CParamDef) ->
	  gen_funarg NOP a
      | VParamDef ->
	  gen_addr a
      | _ -> failwith "gen_arg"
  end
  else if scalar f.d_type then begin
    match f.d_kind with
	(ParamDef | CParamDef) -> 
	  gen_expr a;
	  let s = mem_kind f.d_type in
	  (match s with 
	      CharT | ShortT -> gen (ALIGN s) 
	    | _ -> ())
      | VParamDef ->
	  gen_addr a
      | _ -> failwith "gen_arg"
  end
  else if is_record f.d_type then begin
    match f.d_kind with
	(ParamDef | CParamDef) ->
	  gen_addr a
      | VParamDef ->
	  gen_recarg a
      | _ -> failwith "gen_arg"
  end
  else if is_flex f.d_type then
    gen_flexarg f.d_type a
  else if is_array f.d_type then
    gen_addr a
  else
    failwith "gen_arg"

(* Push a (code, statlink) pair and use inst on the static link *)
and gen_funarg inst a =
  match a.e_guts with
      Name x ->
	let d = get_def x in
	begin match d.d_kind with
	    ProcDef ->
	      if d.d_level = 0 then
		gen (CONST (integer 0))
	      else
		gen_local d.d_level 0;
	      gen inst;
	      gen (GLOBAL d.d_lab)
	  | (ParamDef | CParamDef) ->
	      gen_local d.d_level (d.d_offset + word_size);
	      load_addr ();
	      gen inst;
	      gen_local d.d_level d.d_offset;
	      load_addr ()
	  | _ ->
	      gen (CONST (integer 0));
	      gen inst;
	      gen_expr a
	end
    | _ ->
	gen (CONST (integer 0));
	gen inst;
	gen_expr a

(* gen_recarg -- push address and descriptor of record *)
and gen_recarg a =
  match a.e_guts with
      Name x ->
	let d = get_def x in
	if d.d_kind = VParamDef then begin
	  gen_local d.d_level (d.d_offset + word_size);
	  load_addr ();
	  gen_local d.d_level d.d_offset;
	  load_addr ();
	end
	else begin
	  gen (GLOBAL a.e_type.t_desc);
	  gen_addr a
	end
    | Deref p -> 
	gen_expr p;
	if !Config.boundchk then null_check p;
	gen (DUP 0);
	gen (CONST (integer (-word_size)));
	gen (BINOP (PtrT, PlusA));
	load_addr ();
	gen SWAP
    | _ -> 
	gen (GLOBAL a.e_type.t_desc);
	gen_addr a

(* gen_flexarg -- push addr+bound for flex array arg *)
and gen_flexarg t a =
  if same_types (base_type t) bytetype then begin
    gen_addr a;
    if not (is_flex a.e_type) then 
      gen (CONST (integer (size_of a)))
    else begin
      let t1 = flex_base a.e_type in
      gen (CONST (integer (t1.t_rep.m_size)));
      for i = 1 to flexity a.e_type do
	gen_bound i a (dup 2);
	gen (BINOP (IntT, Times))
      done
    end;
    gen SWAP
  end else begin
    let e0 = sub_base a in
    let us = subscripts a in
    gen_addr e0;
    for i = flexity t downto 1 do
      gen_bound (List.length us + i) e0 (dup 0);
      gen SWAP
    done;
    gen_offset e0 us;
    gen (BINOP (PtrT, PlusA))
  end

(* gen_builtin -- generate code to call a built-in procedure *)
and gen_builtin q args =
  match q.b_id, args with
      ChrFun, [e1] ->
	gen_expr e1;
	gen (CONV (IntT, CharT))

    | OrdFun, [e1] ->
	gen_expr e1

    | OddFun, [e1] ->
	gen_expr e1;
	gen (CONST (integer 1));
	gen (BINOP (IntT, BitAnd));
	gen (CONST (integer 0));
	gen (BINOP (IntT, Neq));

    | AshFun, [e1; e2] ->
	gen_expr e2;
	gen_expr e1;
	call_proc "ASH" 2 inttype

    | LslFun, [e1; e2] ->
	gen_expr e1; gen_expr e2; gen (BINOP (IntT, Lsl))
    | LsrFun, [e1; e2] ->
	gen_expr e1; gen_expr e2; gen (BINOP (IntT, Lsr))
    | AsrFun, [e1; e2] ->
	gen_expr e1; gen_expr e2; gen (BINOP (IntT, Asr))

    | NewProc, e1::_ ->
	let t = base_type e1.e_type in
	begin match t.t_guts with
	    (RecordType _ | ArrayType _) -> 
	      gen (CONST (integer t.t_rep.m_size));
	      if t.t_desc = nosym then 
		gen (CONST (integer 0)) 
	      else 
		gen (GLOBAL t.t_desc);
	      gen_addr e1;
	      call_proc "NEW" 3 voidtype
	  | FlexType _ -> 
 	      let n = flexity t in
 	      let t0 = flex_base t in
 	      for i = n downto 1 do
 		gen_expr (List.nth args i)
 	      done;
 	      gen (CONST (integer n));
	      gen (CONST (integer t0.t_rep.m_size));
	      push_map t0;
 	      gen_addr e1;
 	      call_proc "NEWFLEX" (n+4) voidtype
	  | _ -> failwith "NewProc"
	end

    | LenFun, v::_ ->
	let n = if List.length args = 1 then 1
	  else int_of_integer (int_value (value_of (List.nth args 1))) in
	let e0 = sub_base v in
	let us = subscripts v in
	(* Bug?: any side effects of the subscripts are lost *)
	gen_bound (List.length us + n) e0 (function () -> gen_addr e0)

    | (IncProc | DecProc), e1::_ ->
	begin match op_kind e1.e_type with
	    IntT ->
	      let k = mem_kind e1.e_type in
	      gen_addr e1;
	      gen (DUP 0);
	      gen (LOAD k);
	      if List.length args = 1 then
		gen (CONST (integer 1))
	      else
		gen_expr (List.nth args 1);
	      if q.b_id = IncProc then 
		gen (BINOP (IntT, Plus))
	      else 
		gen (BINOP (IntT, Minus));
	      gen SWAP;
	      gen (STORE k)
	  | LongT ->
	      if List.length args = 1 then
		gen (TCONST (LongT, intval 1))
	      else
		gen_expr (List.nth args 1);
	      gen_addr e1;
	      if q.b_id = IncProc then
		call_proc "INCLONG" 3 longint
	      else
		call_proc "DECLONG" 3 longint
	  | _ -> failwith "IncProc"
	end

    | (InclProc | ExclProc), [e1; e2] ->
	gen_addr e1;
	gen (DUP 0);
	gen (LOAD IntT);
	gen_expr e2;
	if !Config.boundchk then begin
	  gen (CONST (integer set_size));
	  gen (BOUND !code_line)
	end;
	gen (MONOP (IntT, Bit));
	if q.b_id = InclProc then
	  gen (BINOP (IntT, BitOr))
	else begin
	  gen (MONOP (IntT, BitNot));
	  gen (BINOP (IntT, BitAnd))
	end;
	gen SWAP;
	gen (STORE IntT)

    | AbsFun, [e1] ->
	let t = op_kind e1.e_type in
	gen_expr e1;
	begin match t with
	    IntT -> call_proc "ABSINT" 1 inttype
          | LongT -> call_proc "ABSQUAD" 2 longint
	  | FloatT -> call_proc "ABSREAL" 1 realtype
	  | DoubleT -> call_proc "ABSLONG" 2 longreal
	  | _ -> failwith "ABS"
	end

    | Entier, [e1] ->
	let t = op_kind e1.e_type in
	gen_expr e1;
	begin match t with
	    FloatT -> call_proc "INTREAL" 1 inttype
	  | DoubleT -> call_proc "INTLONG" 2 inttype
	  | _ -> failwith "ENTIER"
	end

    | Assert, e1::_ ->
	if !Config.boundchk then begin
	  let lab1 = label () in
	  gen_cond true lab1 e1;
	  if List.length args = 1 then
	    gen (CONST (integer 0))
	  else
	    gen_expr (List.nth args 1);
	  gen (EASSERT !code_line);
	  gen_lab lab1
        end

    | AdrFun, [e1] ->
	gen_addr e1

    | ValFun, [e1; e2] ->
	gen_expr e2

    | BitFun, [e1; e2] ->
	gen_expr e1;
	gen (LOAD IntT);
	gen_expr e2;
	gen (MONOP (IntT, Bit)); 
	gen (BINOP (IntT, BitAnd)); 
	gen (CONST (integer 0));
	gen (BINOP (IntT, Neq))

    | GetProc, [e1; e2] ->
	let k = mem_kind e2.e_type in
	gen_expr e1;
	gen (LOAD k);
	gen_addr e2;
	gen (STORE k);

    | PutProc, [e1; e2] ->
	let k = mem_kind e2.e_type in
	gen_expr e2;
	gen_expr e1;
	gen (STORE k)

    | _ -> 
	failwith (sprintf "can't generate code for $ with $ args"
	  [fStr q.b_name; fNum (List.length args)])

(* gen_cond -- generate code to branch on a condition *)
and gen_cond sense lab test =
  match test.e_guts with
      Const (v, t) ->
	if sense = (int_value v <> integer 0) then
          gen (JUMP lab)

    | Monop (Not, e) ->
        gen_cond (not sense) lab e

    | Binop (And, e1, e2) ->
	if sense then begin
	  let lab1 = label () in
	  gen_cond false lab1 e1;
	  gen_cond true lab e2;
	  gen_lab lab1
	end
	else begin
	  gen_cond false lab e1;
	  gen_cond false lab e2
	end

    | Binop (Or, e1, e2) ->
	if not sense then begin
	  let lab1 = label () in
	  gen_cond true lab1 e1;
	  gen_cond false lab e2;
	  gen_lab lab1
	end
	else begin
	  gen_cond true lab e1;
	  gen_cond true lab e2
	end

    | _ ->
        gen_expr test;
        gen (JUMPB (sense, lab))

and gen_condval sense e =
  match e.e_guts with
      Binop (And, e1, e2) when not (conditional e2) ->
	(* No need to generate jumping code for e2 *)
	let lab1 = label () and lab2 = label () in
	gen_cond true lab1 e1;
	gen (CONST (integer (if sense then 0 else 1)));
	gen (JUMP lab2);
	gen (LABEL lab1);
	gen_expr e2;
	if not sense then gen (MONOP (BoolT, Not));
	gen (LABEL lab2)

    | Binop (Or, e1, e2) when not (conditional e2) ->
	(* No need to generate jumping code for e2 *)
	let lab1 = label () and lab2 = label () in
	gen_cond false lab1 e1;
	gen (CONST (integer (if sense then 1 else 0)));
	gen (JUMP lab2);
	gen (LABEL lab1);
	gen_expr e2;
	if not sense then gen (MONOP (BoolT, Not));
	gen (LABEL lab2)

    | Monop (Not, e1) ->
	gen_condval (not sense) e1

    | _ ->
	let lab1 = label () and lab2 = label () in
	gen_cond (not sense) lab1 e;
	gen (CONST (integer 1));
	gen (JUMP lab2);
	gen_lab lab1;
	gen (CONST (integer 0));
	gen_lab lab2

and gen_typetest e tn =
  let d = get_def tn in
  if is_pointer d.d_type then begin
    gen_expr e;
    if !Config.boundchk then null_check e;
    gen (CONST (integer (-word_size)));
    gen (BINOP (PtrT, PlusA));
    gen_typematch (base_type d.d_type)
  end
  else if is_record d.d_type then begin
    begin match e.e_guts with
	Name x ->
	  let dx = get_def x in
	  if dx.d_kind = VParamDef then
	    gen_local dx.d_level (dx.d_offset + word_size)
	  else
	    failwith "type test 2";
      | Deref e1 ->
	  gen_expr e1;
	  if !Config.boundchk then null_check e1;
	  gen (CONST (integer (-word_size)));
	  gen (BINOP (PtrT, PlusA))
      | _ -> 
	  expr_fail "type test" e
    end;
    gen_typematch d.d_type
  end
  else
    failwith "type test 3"

and gen_element =
  function
      Single x ->
	gen_expr x;
	if !Config.boundchk then begin
	  gen (CONST (integer set_size));
	  gen (BOUND !code_line)
	end;
	gen (MONOP (IntT, Bit))
    | Range (x, y) ->
	(* {x..y} = {0..y} * {x..31} *)
	(* For bound checks, the allowable range for x is 0..32,
	   and the allowable range for y is -1..31: the actual 
	   check is that y+1 is in 0..32. *)
	gen_expr y;
	gen (MONOP (IntT, Inc));	(* y+1 *)
	if !Config.boundchk then begin
	  gen (CONST (integer (set_size+1)));
	  gen (BOUND !code_line)
	end;
	gen (MONOP (IntT, Bit));	(* bit(y+1) *)
	gen (MONOP (IntT, Dec));	(* bits(0..y) *)

	gen_expr x;
	if !Config.boundchk then begin
	  gen (CONST (integer (set_size+1)));
	  gen (BOUND !code_line)
	end;
	gen (MONOP (IntT, Bit));	(* bit(x) *)
	gen (MONOP (IntT, Dec));	(* bits(0..x-1) *)
	gen (MONOP (IntT, BitNot));	(* bits(x..31) *)

	gen (BINOP (IntT, BitAnd))

let gen_rec_addr v desc =
  match v.e_guts with
      Name x ->
	let d = get_def x in
	if !Config.boundchk && d.d_kind = VParamDef then begin
	  let lab1 = label () in
	  gen_local d.d_level (d.d_offset + word_size);
	  gen (LOAD IntT);
	  gen (GLOBAL desc);
	  gen (JUMPC (PtrT, Eq, lab1));
	  gen (ERROR ("E_ASSIGN", !code_line));
	  gen_lab lab1
	end;
	gen_addr v
    | Deref p ->
	gen_expr p;
	if !Config.boundchk then begin
	  let lab1 = label () in
	  null_check p;
	  gen (DUP 0);
	  gen (CONST (integer (-word_size)));
	  gen (BINOP (PtrT, PlusA));
	  gen (LOAD IntT);
	  gen (GLOBAL desc);
	  gen (JUMPC (PtrT, Eq, lab1));
	  gen (ERROR ("E_ASSIGN", !code_line));
	  gen_lab lab1
	end;
      | _ ->
	gen_addr v

(* gen_stmt -- generate code for a statement *)
let rec gen_stmt exit_lab s =
  set_loc s.s_loc;
  match s.s_guts with
      Assign (v, e) ->
	let t = v.e_type in
	if is_proc t then begin
	  gen_funarg (CHECK (GlobProc, !code_line)) e;
	  gen_addr v;
	  gen (STORE IntT)
	end
	else if scalar t then begin
	  gen_expr e;
	  gen_addr v;
	  gen (STORE (mem_kind t))
	end
	else if is_string_const e then begin
	  gen_flexarg strtype v;
	  gen_flexarg strtype e;
	  call_proc "COPY" 4 voidtype
	end
	else if is_flex t then begin
	  let t0 = flex_base t in
	  gen_flexarg t v;
	  gen_flexarg t e;
	  gen (CONST (integer (flexity t)));
	  gen (CONST (integer t0.t_rep.m_size));
	  call_proc "FLEXASSIGN" 6 voidtype
	end
	else begin
	  if is_record t then
	    gen_rec_addr v t.t_desc
	  else
	    gen_addr v;
	  gen_addr e;
	  gen (CONST (integer t.t_rep.m_size));
	  gen FIXCOPY 
	end

    | SimAssign pairs ->
	List.iter (fun (e1, e2) -> gen_expr e2; gen_addr e1) pairs;
	List.iter (fun (e1, e2) -> 
	  let t = e1.e_type in gen (STORE (mem_kind t))) pairs

    | ProcCall e ->
        gen_expr e;
	if size_of e > 0 then
	  gen (POP (count_of e.e_type))

    | Return res ->
        begin 
	  match res with 
	      Some e -> 
		gen_expr e;
		gen (RETURN (op_kind e.e_type))
	    | None -> 
		gen (RETURN VoidT)
	end

    | IfStmt (arms, elsept) ->
	let lab_end = label () in
	List.iter (fun (cond, thenpt) ->
	    let lab1 = label () in
	    gen_cond false lab1 cond;
	    gen_stmt exit_lab thenpt;
	    gen (JUMP lab_end);
	    gen_lab lab1)
	  arms;
	gen_stmt exit_lab elsept;
	gen_lab lab_end

    | CaseStmt (switch, arms, default) ->
	let lab1 = label () and lab2 = label ()
        and caselabs = List.map (function _ -> label ()) arms in

	let make_cases lab (vs, body) =
	  let f =
	      function 
		  Single e -> 
		    let v = int_value (value_of e) in (v, v, lab)
		| Range (e1, e2) -> 
		    let v1 = int_value (value_of e1)
		    and v2 = int_value (value_of e2) in (v1, v2, lab) in
	  List.map f vs 

	and gen_arm lab (vs, body) =
	  gen_lab lab;
	  gen_stmt exit_lab body;
	  gen (JUMP lab2) in

	gen_expr switch;
	let line = !code_line in
	Switch.switch (List.concat (List.map2 make_cases caselabs arms)) lab1;
	Stack.pop 1;
	List.iter2 gen_arm caselabs arms;
	gen_lab lab1;
	begin match default with
	    Some ss -> gen_stmt exit_lab ss
	  | None -> if !Config.boundchk then gen (ERROR ("E_CASE", line));
	end;
	gen_lab lab2

    | WhileStmt ((test1, body1)::arms) ->
	let lab1 = label () and lab_test = label () in
	gen (JUMP lab_test);
	gen_lab lab1;
        gen_stmt exit_lab body1;
	gen_lab lab_test;
	code_line := 0;
        gen_cond true lab1 test1;
	List.iter (fun (test, body) ->
	    let lab2 = label () in
	    gen_cond false lab2 test;
	    gen_stmt exit_lab body;
	    gen (JUMP lab_test);
	    gen_lab lab2)
	  arms

    | WhileStmt [] -> failwith "gen_stmt: empty while"

    | RepeatStmt (body, test) ->
	let lab1 = label () in
	gen_lab lab1;
	gen_stmt exit_lab body;
	gen_cond false lab1 test

    | LoopStmt body ->
	let lab1 = label () and lab2 = label () in
	gen_lab lab1;
	gen_stmt lab2 body;
	gen (JUMP lab1);
	gen_lab lab2

    | ExitStmt ->
	gen (JUMP exit_lab)

    | ForStmt (var, lo, hi, step, body, tmp) ->
	let lab1 = label () and lab2 = label () in
	let memk = mem_kind var.e_type in
	let kind = op_kind var.e_type in
	let inc =  int_value (value_of step) in
	let gen_upb =
	  match hi.e_guts with 
	      Const (_, _) -> 
		(function () -> gen_expr hi)
	    | _ ->
		let off = (!tmp).d_offset in
		gen_expr hi; gen (LOCAL off); gen (STORE memk);
		(function () -> gen (LOCAL off); gen (LOAD memk)) in

 	(* var := lo; goto lab2 *)
  	gen_expr lo; gen_addr var; gen (STORE memk);
 	gen (JUMP lab2);
 
 	(* lab1: body *)
  	gen_lab lab1;
  	gen_stmt exit_lab body;
 
 	(* var := var + inc *)
 	gen_expr var; gen_const kind (IntVal inc);
	gen (BINOP (kind, Plus)); gen_addr var; gen (STORE memk);
 
 	(* lab2: if var <= hi goto lab1 *)
 	gen_lab lab2;
 	gen_expr var; gen_upb ();
 	gen (JUMPC (kind, (if inc > integer 0 then Leq else Geq), lab1))

    | WithStmt (branches, else_part) ->
	let labn = label () in

	let gen_branch (e, tn, body) =
	  let lab1 = label () in
	  gen_typetest e tn;
	  gen (JUMPB (false, lab1));
	  gen_stmt exit_lab body;
	  gen (JUMP labn);
	  gen_lab lab1 in

	List.iter gen_branch branches;
	begin match else_part with
	    Some s -> 
	      gen_stmt exit_lab s
	  | None -> 
	      if !Config.boundchk then 
		gen (ERROR ("E_WITH", !code_line))
	end;
	gen_lab labn

    | LocalStmt (decls, body) -> gen_stmt exit_lab body

    | Seq ss -> 
	let rec walk = 
	  function 
	      [] -> ()
	    | s::ss' ->
		gen_stmt exit_lab s; 
		walk ss' in
	walk ss

    | Skip -> ()

    | ErrStmt ->
	failwith "igen ErrStmt"

(* gen_copy -- generate code to copy aggregate value params *)
let gen_copy fps = 
  (* In the case where the parameter is a string constant shorter than 
     the formal, this code copies junk beyond the terminating 0X. In 
     extreme cases, it could cause a segfault. *)
  let copy fp =
    if fp.d_kind = ParamDef && not (scalar fp.d_type) then begin
      if is_flex fp.d_type then begin
	gen (LOCAL fp.d_offset);
	gen (LOCAL (fp.d_offset + word_size));
	gen (LOAD IntT);
	for i = 2 to flexity fp.d_type do
	  gen (LOCAL (fp.d_offset + i*word_size));
	  gen (LOAD IntT);
	  gen (BINOP (IntT, Times))
	done;
	gen (CONST (integer (flex_base fp.d_type).t_rep.m_size));
	gen (BINOP (IntT, Times));
	gen FLEXCOPY 
      end
      else begin
	gen (LOCAL fp.d_offset);
	gen (LOCAL fp.d_param);
	gen (LOAD IntT);
	gen (CONST (integer fp.d_type.t_rep.m_size));
	gen FIXCOPY
      end
    end in
  List.iter copy fps

let gen_procdef d loc fsize body =
  let p = get_proc d.d_type in
  let line = line_num loc in
  code_line := line;
  level := d.d_level+1;
  Stack.reset ();
  if d.d_level > 0 then gen SAVELINK;
  gen_copy p.p_fparams;
  gen_stmt nolab body;
  if kind_of p.p_result = VoidT then
    gen (RETURN VoidT)
  else
    gen (ERROR ("E_RETURN", line));

  Peepopt.reduce ();
  put "PROC $ $ $ $" 
    [fSym d.d_lab; fNum (!fsize / 4); 
      fNum (Stack.max_depth ()); fSym (frame_map d)];
  if loc <> no_loc then Peepopt.put_line line;
  Peepopt.flush ();
  put "END\n" []

(* gen_proc -- generate code for a procedure, ignore other declarations *)
let rec gen_proc = 
  function
      ProcDecl (_, x, _, Block (decls, body, fsize), _) ->
        List.iter gen_proc decls;
	let d = get_def x in
        gen_procdef d x.x_loc fsize body
    | PrimDecl (x, _, name, _) ->
	let d = get_def x in
	put "PRIMDEF $ $ 0 $\n" 
	  [fSym d.d_lab; fStr name; fSym (frame_map d)];
    | _ -> ()

(* gen_string -- generate code for a string constant *)
let gen_string (lab, s) = 
  let s' = s ^ "\000" in
  put "! String \"$\"" [fStr (String.escaped s)];
  put "DEFINE $" [fSym lab];
  let hex = "0123456789ABCDEF" in
  let n = String.length s' and r = ref 0 in
  while !r < n do
    let k = min (n - !r) 32 in
    printf "STRING " [];
    for i = !r to !r+k-1 do
      let c = int_of_char s'.[i] in
      printf "$$" [fChr (hex.[c / 16]); fChr (hex.[c mod 16])]
    done;
    printf "\n" [];
    r := !r + k
  done;
  printf "\n" []

(* gen_descriptor -- generate a descriptor *)
let gen_descriptor t =
  put "! Descriptor for $" [fId t.t_name];
  put "DEFINE $" [fSym t.t_desc];
  begin 
    match t.t_guts with
	RecordType r ->
	  if r.r_abstract then
	    put_int 0
	  else begin
	    let alabel = sprintf "$.%anc" [fStr t.t_desc] in
	    put_sym (type_map t);
	    put_int r.r_depth;
	    put_sym alabel;
	    List.iter (function d -> put_sym d.d_lab) r.r_methods;
	    put "" [];
	    put "DEFINE $" [fSym alabel];
	    List.iter (function t' -> put_sym t'.t_desc) 
	      (List.rev (ancestors t))
	  end
      | _ -> 
	  put_sym (type_map t)
  end;
  put "" []

(* translate -- generate code for the whole program *)
let translate stamp 
    (Module (m, imports, body, glodefs, _)) =
  let lcount = if !Config.linecount then num_lines () else 0 in
  put "MODULE $ $ $" [fId m.x_name; fHex stamp; fNum lcount];
  List.iter 
    (function (x, x', st) -> 
      if x' <> intern "SYSTEM" then put "IMPORT $ $" [fId x'; fHex !st]) 
    imports;
  List.iter (function s -> put "PRIM $" [fSym s]) (prim_table ());
  put "ENDHDR\n" [];

  begin match body with
      Block (globals, init, fsize) ->
	List.iter gen_proc globals;
	if init.s_guts <> Skip then begin
	  let d = get_def m in
	  gen_procdef d no_loc fsize init
	end
    | NoBlock ->
	failwith "translate"
  end;

  if List.exists (function d -> d.d_kind = VarDef) !glodefs then begin
    put "! Global variables" [];
    List.iter (function d ->
	match d.d_kind with
	    VarDef ->
	      put "GLOVAR $ $" [fSym d.d_lab; fNum d.d_type.t_rep.m_size]
 	  | _ -> ())
      !glodefs;
    put "" [];

    let gcmap = 
      List.concat (List.map (function d ->
	  if d.d_kind = VarDef && d.d_map <> [] 
	  then [(d.d_lab, d.d_map)] else [])
	!glodefs) in
    if gcmap <> [] then begin
      put "! Pointer map" [];
      put "DEFINE $.%gcmap" [fId !current];
      List.iter (function (s, m) -> 
		  put_sym "GC_BASE"; put_sym s; put_map m) gcmap;
      put_sym "GC_END";
      put "" []
    end
  end;
  List.iter gen_string (string_table ());
  List.iter gen_descriptor (desc_table ());
  put_maps ();
  put "! End of file" []

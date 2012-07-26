(*
 * print.mli
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
 * $Id: print.mli 1678 2011-03-15 20:27:21Z mike $
 *)

type arg =
    Str of string 		(* String *)
  | Chr of char 		(* Character *)
  | Ext of ((string -> arg list -> unit) -> unit)  (* Extension *)

val fNum: int -> arg		(* Decimal number *)
val fHex: int -> arg		(* Hexadecimal number *)
val fFlo: float -> arg		(* Floating-point number *)
val fStr: string -> arg		(* String *)
val fChr: char -> arg 		(* Character *)
val fBool: bool -> arg		(* Boolean *)
val fExt: ((string -> arg list -> unit) -> unit) -> arg  (* Extension *)

(* |fFixNum| -- Fixed-width number (val, width) *)
val fFixNum : int * int -> arg

val fNum32: int32 -> arg
val fHex32: int32 -> arg

(* |fMeta| -- insert output of recursive call to |printf| *)
val fMeta : string -> arg list -> arg

val fSeq : ('a -> arg) * string -> 'a list -> arg

(* |fList| -- format a comma-separated list *)
val fList : ('a -> arg) -> 'a list -> arg

(* |printf| -- print on standard output *)
val printf : string -> arg list -> unit

(* |fprintf| -- print to a file *)
val fprintf : out_channel -> string -> arg list -> unit

(* |sprintf| -- print to a string *)
val sprintf : string -> arg list -> string

val do_print : (char -> unit) -> string -> arg list -> unit

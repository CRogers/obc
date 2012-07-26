(*
 *  Oxford Oberon-2 compiler
 *  stack.mli
 *  Copyright (C) J. M. Spivey 1995, 1998
 *
 *  $Id: stack.mli 1592 2010-04-23 17:30:15Z mike $
 *)

(* In order to output a pointer map for the evaluation stack at each
   procedure call, we simulate the effect on the stack of each
   instruction we generate. *)

(* simulate -- note effect of an instruction *)
val simulate : Icode.icode -> unit

(* reset -- reset the simulated stack *)
val reset : unit -> unit

(* pop -- pop values from the simulated stack *)
val pop : int -> unit

(* mark -- mark top item as pointer *)
val mark : unit -> unit

(* make_map -- make a pointer map before calling a routine with N params *)
val make_map : int -> Dict.gcmap

(* max_depth -- find max stack depth for procedure *)
val max_depth : unit -> int

(* fStack -- format the stack state for printing *)
val fStack : Print.arg

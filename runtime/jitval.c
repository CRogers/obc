/*
 * jitval.c
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
 * $Id: jitval.c 1646 2010-12-15 11:39:11Z mike $
 */

#include "obx.h"
#include "keiko.h"
#include "jit.h"
#include "decode.h"
#include <assert.h>

char *jitval_rcsid = "$Id: jitval.c 1646 2010-12-15 11:39:11Z mike $";

/*
Possible compile-time values

     OP          FIELDS USED    MEANING

     REG         reg		reg
     CON             val	val
     STACK           val siz	mem_s[BP + val] where s = 4*siz
     ADDR        reg val	reg + val
     LDKW, LDKF      val	konst_4[val]
     LDKD, LDKQ      val	konst_8[val]
     LOADs       reg val	mem_s[reg + val] for s = C, S, W, D, F, Q
     TYPETEST+n  reg val	[ancestor_n(reg) == val]

Of these, LDKW and LDKD refer to the pool of constants for the procedure
being compiled.  TYPETEST refers to the result of a type test to determine
whether the level n ancestor of the type whose descriptor is in reg is
equal to val: it's delayed to find out whether the next operation is an
assignment or a jump.
*/

#ifdef DEBUG
/* show -- print a value for debugging */
static void show(ctvalue v) {
     switch (v->v_op & 0xff) {
     case I_REG: 
	  printf("reg %s", regs[v->v_reg].r_name); break;

     case I_CON:
	  printf("const %d", v->v_val); break;

     case I_STACK: 
	  printf("stack %d", v->v_val); break;

     case I_TYPETEST:
	  printf("[TYPETEST %d %s %d]", v->v_op >> 16, 
		 regs[v->v_reg].r_name, v->v_val);
	  break;

     default:
	  printf("[%s %d", instrs[v->v_op & 0xff].i_name, v->v_val);
	  if (v->v_reg != ZERO) printf("(%s)", regs[v->v_reg].r_name);
	  printf("]");
     }
}

/* dumpregs -- print values cached in all registers */
void dumpregs(void) {
     reg r;

     for (r = 0; r < NREGS; r++) {
	  if (regs[r].r_class == 0) continue;
	  if (r == rF0) printf("\n");
	  printf("  %s(%d)", regs[r].r_name, regs[r].r_refct);
	  if (cached(r)) {
	       printf(" = "); show(&regs[r].r_value);
	  }
     }
     printf("\n");
}
#endif

static bool same(ctvalue v, ctvalue w) {
     return (v->v_op == w->v_op && v->v_val == w->v_val 
	     && v->v_reg == w->v_reg && v->v_size == w->v_size);
}

void set_cache(reg r, ctvalue v) {
#ifdef DEBUG
     if (dflag > 2) {
	  printf("\tCache %s = ", regs[r].r_name);
	  show(v);
	  printf("\n");
     }
#endif

     regs[r].r_value = *v;
}

/* alias -- conservatively test if two values may be aliases */
static bool alias(ctvalue v, ctvalue w) {
     /* Assume v is a LOAD */

     switch (w->v_op) {
     case I_LOADC:
     case I_LOADS:
     case I_LOADW:
     case I_LOADD:
     case I_LOADF:
     case I_LOADQ:
	  return (v->v_reg != ZERO || w->v_reg != ZERO || same(v, w));

     default:
	  return FALSE;
     }
}

/* kill_alias -- forget all cached values that might alias v */
static void kill_alias(ctvalue v) {
     reg r;

#ifdef DEBUG
     if (dflag > 2) {
	  printf("Unalias(");
	  show(v);
	  printf(")\n");
     }
#endif

     for (r = 0; r < NREGS; r++) {
	  if (alias(v, &(regs[r].r_value))) 
	       kill(r);
     }
}


/* Compile-time evaluation stack */

#define STACK 32

static struct ctvalue vstack[STACK];  /* Stack of value descriptions */
static int sp = 0;		/* Number of stack items */

static int offset[STACK];       /* Offset of each item from stack base */
static int pdepth = 0;		/* Total size of runtime stack */
static reg breg;		/* Base register for runtime stack */
static int base;		/* Offset of stack base from breg */

/* In normal procedures, breg = rBP and base = 4 * frame size.  But some
   procedures require a variable-sized area on the stack for copying
   open array parameters passed by value, and they set breg = rSP and
   base = 0, after generating code to set rSP to the base of the
   working stack area. */

void init_stack(int frame) {
     sp = 0; 
     pdepth = 0;
     base = -4*frame;
     breg = rBP;
}

int count_args(int size) {
     int nargs = 0;

     while (nargs < sp-1 
	    && offset[sp-nargs-2] < -pdepth + 4 + 4*size) 
	  nargs++;

     return nargs;
}

/* flex_space -- allocate space to copy an open array parameter */
void flex_space(reg nreg) {
     reg r0 = rSP;

     if (breg == rBP) {
	  /* Disable rI5 and use it as stack pointer */
	  assert(regs[rI5].r_refct == 0);
	  regs[rI5].r_refct = OMEGA+1;

	  if (base == 0) 
	       r0 = rBP;
	  else
	       g3rri(SUB, rSP, rBP, -base);

	  breg = rSP; base = 0;
     }

     g3rrr(SUB, rSP, r0, nreg);
     g3rri(AND, rSP, rSP, ~0x3);
}

/* get_sp -- compute value of Oberon stack pointer */
void get_sp(reg r) {
     g3rri(SUB, r, breg, pdepth-base);
}

/* set -- assign to a stack slot */
static void set(int i, int op, int type, int val, reg r, int s) {
     ctvalue v = &vstack[i];
     reserve(r);

     if (op == I_STACK) val = offset[i];

     v->v_op = op; v->v_type = type; v->v_val = val; 
     v->v_reg = r; v->v_size = s;

#ifdef DEBUG
     if (dflag > 1) {
	  printf("\t<%d> = ", i);
	  show(v);
	  printf(" (%d/%d)\n", offset[i], s);
     }
#endif
}

/* push -- push a value onto the eval stack */
void push(int op, int type, reg r, int val, int size) {
     pdepth += 4*size;
     offset[sp] = -pdepth;
     set(sp++, op, type, val, r, size);
}

/* pop -- pop one or more values from the eval stack */
void pop(int n) {
     int i;

     for (i = sp - n; i < sp; i++) 
	  rfree(vstack[i].v_reg);

     sp -= n;
     pdepth = (sp == 0 ? 0 : -offset[sp-1]);
}

/* peek -- access value near top of stack */
ctvalue peek(int n) {
     return &vstack[sp-n];
}

/* unlock -- unlock registers used near the top of the stack */
void unlock(int n) {
     int i;

     for (i = sp; i < sp + n; i++)
	  runlock(vstack[i].v_reg);
}

/* save_stack -- record stack contents at a forward branch */
void save_stack(codepoint lab) {
     int i, map = 0;

     if (sp > 32) panic("too many items to save");

     /* Make a bitmap showing the size of each item */
     for (i = 0; i < sp; i++) {
	  if (vstack[i].v_size == 2)
	       map |= (1 << i);
     }


     lab->l_depth = sp;
     lab->l_stack = map;
}

/* restore_stack -- restore stack state at target of a forward branch */
void restore_stack(codepoint lab) {
     int n = lab->l_depth, map = lab->l_stack, i, s;

#ifdef DEBUG
     if (dflag > 1 && n > 0) printf("[Restore %d]\n", n);
#endif

     sp = 0; pdepth = 0;
     for (i = 0; i < n; i++) {
	  s = (map & (1 << i) ? 2 : 1);
	  push(I_STACK, INT, ZERO, 0, s);
     }
}


/* Value motion */

/* move_from_frame -- move vstack[i] so that it is not in the runtime stack */
ctvalue move_from_frame(int i) {
     ctvalue v = &vstack[sp-i];

     if (v->v_op == I_STACK) {
	  reg r = move_to_reg(i, INT);
	  runlock(r);
     }

     return v;
}

/* move_to_frame -- force vstack[sp-i] into the runtime stack */
void move_to_frame(int i) {
     ctvalue v = &vstack[sp-i];
     reg r = ZERO;

     if (v->v_op != I_STACK) {
	  switch (v->v_type) {
	  case INT:
#ifdef INT64	       
	       if (v->v_size == 2) {
		    move_longval(v, breg, base+offset[sp-i]);
		    rfree(v->v_reg);
		    break;
	       }
#endif

	       r = move_to_reg(i, INT); runlock(r); rfree(r);
	       g3rri(STW, r, breg, base+offset[sp-i]);
	       break;

	  case FLO:
	       r = move_to_reg(i, FLO); runlock(r); rfree(r);
	       if (v->v_size == 1)
		    g3rri(STW, r, breg, base+offset[sp-i]);
	       else
		    g3rri(STD, r, breg, base+offset[sp-i]);
	       break;

	  default:
	       panic("move_to_frame");
	  }

	  if (r != ZERO && v->v_op != I_REG && v->v_reg != r) 
	       set_cache(r, v);
	  set(sp-i, I_STACK, v->v_type, 0, ZERO, v->v_size);
     }
}

/* transient -- check if a value is not preserved across a procedure call */
static bool transient(ctvalue v) {
     if (regs[v->v_reg].r_class != 0)
	  return TRUE;

     switch (v->v_op) {
     case I_LOADW:
     case I_LOADF:
	  return (v->v_val == (unsigned) &ob_res);
     case I_LOADQ:
     case I_LOADD:
	  return (v->v_val == (unsigned) &ob_dres);
     default:
	  return FALSE;
     }
}

/* flush_stack -- flush values into the runtime stack */
void flush_stack(int a, int b) {
     int j;

     /* Values vstack[0..sp-b) are flushed if they use an
	     allocable register or the result location.
	Values vstack[sp-b..sp-a) are all flushed (perhaps to
	     become arguments in a procedure call).
	Values vstack[sp-a..sp) are left alone */

     for (j = sp; j > a; j--)
	  if (j <= b || transient(&vstack[sp-j]))
	       move_to_frame(j);
}

void spill(reg r) {
     int i;
     
     for (i = 0; i < sp; i++) {
	  if (vstack[i].v_reg == r)
	       move_to_frame(i);
     }
}

/* load -- load from memory into register */
static reg load(int op, int class, reg r, int val) {
     reg r1;
     rfree(r); r1 = ralloc(class);
     g3rri(op, r1, r, val);
     return r1;
}

/* move_to_reg -- move stack item to a register */
reg move_to_reg(int i, int ty) {
     ctvalue v = &vstack[sp-i];
     reg r, r2;
     codepoint lab;

     if (v->v_op != I_REG) {
	  for (r = 0; r < NREGS; r++) {
	       if (cached(r) 
		   && same(&regs[r].r_value, v) 
		   && member(r, ty)) {
#ifdef DEBUG
		    if (dflag > 1) printf("Hit %s\n", regs[r].r_name);
#endif
		    rfree(v->v_reg);
		    set(sp-i, I_REG, ty, 0, r, v->v_size);
		    return rlock(r);
	       }
	  }
     }

     switch (v->v_op & 0xff) {
     case I_REG:
	  r = rfree(v->v_reg);
	  break;

     case I_CON:
	  r = ralloc(INT);
	  g2ri(MOV, r, v->v_val);
	  break;

     case I_LDKW:
     case I_LDKF:
	  r = ralloc(ty);

	  switch (ty) {
	  case INT:
	       g2ri(MOV, r, * (int *) v->v_val);
	       break;

	  case FLO:
	       g3rri(LDW, r, ZERO, v->v_val);
	       break;

	  default:
	       panic("fixr LDKW");
	  }
	  break;
	  
     case I_LDKD:
	  assert(ty == FLO);
	  r = ralloc(FLO);
	  g3rri(LDD, r, ZERO, v->v_val);
	  break;

     case I_ADDR:
	  rfree(v->v_reg); r = ralloc_suggest(INT, v->v_reg);
	  g3rri(ADD, r, v->v_reg, v->v_val);
	  break;

     case I_LOADW:	
     case I_LOADF:
	  r = load(LDW, ty, v->v_reg, v->v_val);
	  break;

     case I_LOADS:	
	  r = load(LDS, INT, v->v_reg, v->v_val); 
	  break;

     case I_LOADC:	
	  r = load(LDCU, INT, v->v_reg, v->v_val); 
	  break;

     case I_LOADD: 
	  assert(ty == FLO);
	  r = load(LDD, FLO, v->v_reg, v->v_val); 
	  break;

     case I_STACK:
	  if (v->v_size == 1)
	       r = load(LDW, ty, breg, base + v->v_val);
	  else {
	       assert(ty == FLO);
	       r = load(LDD, FLO, breg, base + v->v_val);
	  }
	  break;

     case I_TYPETEST:
	  lab = new_label();
	  rlock(v->v_reg);
	  r = ralloc(INT); 
	  r2 = ralloc_avoid(INT, r);
	  runlock(v->v_reg);
	  g2ri(MOV, r, 0);
	  g3rri(LDW, r2, v->v_reg, 4*DESC_DEPTH);
	  g3rib(BLT, r2, v->v_op >> 16, lab);
	  g3rri(LDW, r2, v->v_reg, 4*DESC_ANCES);
	  g3rri(LDW, r2, r2, 4 * (v->v_op >> 16));
	  g3rri(EQ, r, r2, v->v_val);
	  label(lab);
	  break;

     default:
	  panic("fixr %s\n", instrs[v->v_op].i_name);
	  r = ZERO;
     }

     /* Unusually, e.g. in SYSTEM.VAL(REAL, n+1), a floating point
	value can appear in an integer register, or vice versa. */
     if (rkind(r) != ty) {
	  r2 = ralloc(ty);
	  g2rr(MOV, r2, r);
	  r = r2;
     }

     if (v->v_op != I_STACK && v->v_reg != r)
	  set_cache(r, v);

     set(sp-i, I_REG, ty, 0, r, v->v_size);
     return rlock(r);
}

/* fix_const -- check a stack item is a constant or move it to a register */
ctvalue fix_const(int i, bool rflag) {
     ctvalue v = &vstack[sp-i];

     switch (v->v_op) {
     case I_CON:
	  break;

     case I_LDKW:
	  set(sp-i, I_CON, INT, * (int *) v->v_val, ZERO, 1);
	  break;

     default:
	  if (!rflag)
	       panic("fix_const %s", instrs[v->v_op].i_name);
	  move_to_reg(i, INT);
     }

     return v;
}

/* deref -- perform load operation on top of stack */
void deref(int op, int ty, int size) {
     ctvalue v = &vstack[sp-1];
     reg r1;

     switch (v->v_op) {
     case I_ADDR:
	  pop(1);
	  push(op, ty, v->v_reg, v->v_val, size);
	  break;

     case I_CON:
     case I_LDKW:
	  fix_const(1, FALSE); pop(1); unlock(1);
	  push(op, ty, ZERO, v->v_val, size);
	  break;

     default:
	  r1 = move_to_reg(1, INT); pop(1); unlock(1); 
	  push(op, ty, r1, 0, size); 
	  break;
     }
}

/* unalias -- execute load operations that might alias v */
static void unalias(int a, ctvalue v) {
     int i;

     for (i = sp; i > a; i--) {
	  ctvalue w = &vstack[sp-i];
	  if (alias(v, w)) {
	       if (w->v_op == I_LOADQ)
		    move_to_frame(i);
	       else
		    move_to_reg(i, w->v_type);
	  }
     }
}

/* store -- perform store operation on top of stack */
void store(int ldop, int ty, int s) {
     reg r1;
     ctvalue v;

     deref(ldop, ty, s);							
     v = &vstack[sp-1];
     v->v_type = vstack[sp-2].v_type;
     if (same(v, &vstack[sp-2])) {
	  /* Store into same location as load: mostly for
	     SLIDEW / RESULTW */
	  pop(2);
	  return;
     }

     unalias(2, v); 

     if (ldop == I_LOADQ) {
	  move_longval(&vstack[sp-2], vstack[sp-1].v_reg, vstack[sp-1].v_val);
	  pop(2);
	  return;
     }

     rlock(v->v_reg);
     r1 = move_to_reg(2, v->v_type); 
     pop(2); unlock(2);						

     switch (ldop) {
     case I_LOADW:	g3rri(STW, r1, v->v_reg, v->v_val); break;
     case I_LOADF:	g3rri(STW, r1, v->v_reg, v->v_val); break;
     case I_LOADC:	g3rri(STC, r1, v->v_reg, v->v_val); break;
     case I_LOADS:	g3rri(STS, r1, v->v_reg, v->v_val); break;
     case I_LOADD:	g3rri(STD, r1, v->v_reg, v->v_val); break;

     default:
	  panic("put %s", instrs[ldop].i_name);
     }

     kill_alias(v);

     if (v->v_reg != r1 
	 /* Don't cache truncated values */
	 && ldop != I_LOADC && ldop != I_LOADS)
	  set_cache(r1, v);
}

/* plusa -- add address and offset */
void plusa() {
     ctvalue v1, v2;
     reg r1, r2;

     switch (vstack[sp-2].v_op) {
     case I_CON:
     case I_LDKW:
	  v1 = fix_const(2, FALSE); 
	  v2 = move_to_rc(1); 
	  pop(2); unlock(2);
	  if (v2->v_op == I_CON)
	       push(I_CON, INT, ZERO, v1->v_val + v2->v_val, 1);
	  else
	       push(I_ADDR, INT, v2->v_reg, v1->v_val, 1);
	  break;

     case I_ADDR:
	  v1 = &vstack[sp-2];
	  v2 = move_to_rc(1); 
	  pop(2);
	  if (v2->v_op == I_CON)
	       push(I_ADDR, INT, v1->v_reg, v1->v_val + v2->v_val, 1);
	  else {
	       rlock(v1->v_reg); 
	       r1 = ralloc_suggest(INT, v1->v_reg); 
	       unlock(2);
	       g3rrr(ADD, r1, v1->v_reg, v2->v_reg);
	       push(I_ADDR, INT, r1, v1->v_val, 1);
	  }
	  break;

     default:
	  r1 = move_to_reg(2, INT); 
	  v2 = move_to_rc(1); 
	  pop(2);
	  if (v2->v_op == I_CON) {
	       unlock(2);
	       push(I_ADDR, INT, r1, v2->v_val, 1);
	  } else {
	       r2 = ralloc_suggest(INT, r1); 
	       unlock(2);			
	       g3rrr(ADD, r2, r1, v2->v_reg);		
	       push(I_REG, INT, r1, 0, 1);
	  }
     }
}


#ifdef INT64
/* 64-bit operations */

/* Just for fun, we support 64-bit integers, though the code is
   quite nasty, because there are not really enough registers. */

/* move_long -- move a 64-bit value */
static void move_long(reg rs, int offs, reg rd, int offd) {
     reg r1, r2;
     
     rlock(rs); rlock(rd);
     r1 = ralloc(INT); r2 = ralloc_avoid(INT, r1);
     runlock(rs); runlock(rd);
     g3rri(LDW, r1, rs, offs);
     g3rri(LDW, r2, rs, offs+4);
     g3rri(STW, r1, rd, offd);
     g3rri(STW, r2, rd, offd+4);
}
     
/* half-const -- fetch one or other half of a 64-bit constant */
static int half_const(ctvalue v, int off) {
     switch (v->v_op) {
     case I_CON:
	  if (off == 0)
	       return v->v_val;
	  else
	       return (v->v_val < 0 ? -1 : 0);

     case I_LDKQ:
	  return ((int *) v->v_val)[off];

     default:
	  panic("half_const %s", instrs[v->v_op].i_name);
	  return 0;
     }
}     

/* move_longval -- move a long value into memory */
void move_longval(ctvalue src, reg rd, int offd) {
     /* Move from src to offd(rd) */
     reg r;

     switch (src->v_op) {
     case I_LOADQ:
	  move_long(src->v_reg, src->v_val, rd, offd);
	  break;
     case I_STACK:
	  move_long(breg, base + src->v_val, rd, offd);
	  break;
     case I_LDKQ:
     case I_CON:
	  r = ralloc(INT);
	  g2ri(MOV, r, half_const(src, 0));
	  g3rri(STW, r, rd, offd);
	  g2ri(MOV, r, half_const(src, 1));
	  g3rri(STW, r, rd, offd+4);
	  break;
     default:
	  panic("move_longval %s", instrs[src->v_op].i_name);
     }
}

/* get_halflong -- fetch one or other half of a 64-bit value */
void get_halflong(ctvalue src, int off, reg dst) {
     switch (src->v_op) {
     case I_LOADQ:
	  g3rri(LDW, dst, src->v_reg, src->v_val + 4*off);
	  break;
     case I_STACK:
	  g3rri(LDW, dst, breg, base + src->v_val + 4*off);
	  break;
     case I_LDKQ:
     case I_CON:
	  g2ri(MOV, dst, half_const(src, off));
	  break;
     default:
	  panic("get_halflong %s", instrs[src->v_op].i_name);
     }
}     
#endif

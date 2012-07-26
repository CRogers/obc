/*
 * obx.h
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
 * $Id: obx.h 1646 2010-12-15 11:39:11Z mike $
 */

#ifndef _OBX_H
#define _OBX_H 1

#ifdef TRACE
#define DEBUG 1
#endif

#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h> 
#endif
#include "obcommon.h"

#define SLIMIT 256		/* Min stack space space left (bytes) */

typedef union value value;

typedef void primitive(value *sp);

union value {
     int i;
     float f;
     value *p;
     uchar *x;
     primitive *z;
};

typedef struct proc *proc;
typedef struct module *module;
typedef struct arc *arc;

#ifdef PROFILE
typedef long long unsigned counter;
#endif

struct proc {
     char *p_name;		/* Procedure name */
     value *p_addr;		/* Address of descriptor in data space */
#ifdef PROFILE
     int p_index;		/* Position in listing */
     unsigned p_calls;		/* Call count */
     unsigned p_rec;		/* Call count for recursion */
     counter p_self;		/* Tick count for self */
     counter p_child;		/* Tick count for children */
     arc p_parents;		/* List of callers */
     arc p_children;		/* List of procs we call */
#endif
};

struct module {
     char *m_name;		/* Layout must match proc */
     uchar *m_addr;
     int m_length;
#ifdef PROFILE
     int m_nlines;
     unsigned *m_lcount;
#endif
};

struct opcode { 
     char *i_name;		/* Name */
     char *i_patt;		/* Argument template */
     int i_arg;			/* Argument packed in opcode */
     int i_len;			/* Total length in bytes */
};


/* Global variables */
EXTERN uchar *imem, *dmem;	/* Instruction and data memory arrays */
EXTERN uchar *stack;		/* Program stack */
EXTERN int code_size;		/* Size of program code */
EXTERN int stack_size;		/* Size of main stack */
EXTERN char *libpath;		/* Path to dynamic library */
EXTERN value *entry;		/* Program entry point */
EXTERN value *gcmap;		/* Global pointer map */

#define get1(p)  ((int) ((char) (p)[0]))
#define get2(p)  ((int) ((short) (((p)[1]<<8) + (p)[0])))

EXTERN int nmods, nprocs, nsyms;
EXTERN module *modtab;
EXTERN proc *proctab;
extern unsigned prim_check;
extern primitive *primtab[];
#ifdef TRACE
extern char *primname[];
#endif

EXTERN value _result[2];	/* Procedure result */
#define ob_res _result[0]
#define ob_dres _result[0]

EXTERN value *statlink;		/* Static link for procedure call */
EXTERN int level;		/* Recursion level in bytecode interp. */
#ifdef OBXDEB
EXTERN value *prim_bp;		/* Base pointer during primitive call */
#endif

EXTERN int dflag;
EXTERN bool gflag;
#ifdef PROFILE
EXTERN bool lflag;
#endif
#ifdef TRACE
EXTERN int qflag;
#endif
#ifdef OBXDEB
EXTERN char *debug_socket;
#endif

#define divop_decl(t) \
     t t##_divop(t a, t b, int div) {		\
	  t quo = a / b, rem = a % b;		\
	  if (rem != 0 && (rem ^ b) < 0) {	\
	       rem += b; quo--;			\
	  }					\
	  return (div ? quo : rem);		\
     }


/* profile.c */
#ifdef PROFILE
void prof_enter(value *p, counter ticks, int why);
void prof_exit(value *p, counter ticks);
void prof_init(void);
void prof_reset(proc p);
void profile(FILE *fp);

#define PROF_CALL 1
#define PROF_TAIL 2
#define PROF_PRIM 3
#endif

/* interp.c */
primitive interp, dltrap;
extern struct opcode optable[];

/* xmain.c */
EXTERN int saved_argc;
EXTERN char **saved_argv;

int obgetc(FILE *fp);
void xmain_exit(int status);
void error_exit(int status);

/* support.c */
extern int bit[];
extern value *co_desc;

int ob_div(int a, int b);
int ob_mod(int a, int b);

void int_div(value *sp);
void int_mod(value *sp);

void long_add(value *sp);
void long_sub(value *sp);
void long_mul(value *sp);
void long_div(value *sp);
void long_mod(value *sp);
void long_neg(value *sp);
void long_cmp(value *sp);
void long_flo(value *sp);
void long_ext(value *sp);

#ifdef SPECIALS
int pack(value *code, uchar *env);
value *getcode(int word);
uchar *getenvt(int word);

void pack_closure(value *sp);
void unpack_closure(value *sp);
#endif


/* load_file -- load a file of object code */
void load_file(FILE *bfp);

module make_module(char *name, uchar *addr, int chsum, int nlines);
proc make_proc(char *name, uchar *addr);
void make_symbol(char *kind, char *name, uchar *addr);

void panic(char *, ...);
void obcopy(char *dst, char *src, int n);

void error_stop(char *msg, int line, value *bp, uchar *pc);
void runtime_error(int num, int line, value *bp, uchar *pc);
void rterror(int num, int line, value *bp);
#define liberror(msg) error_stop(msg, 0, bp, NULL)

proc find_symbol(value *p, proc *table, int nelem);
#define find_proc(cp) find_symbol(cp, proctab, nprocs)
#define find_module(cp) ((module) find_symbol(cp, (proc *) modtab, nmods))

#ifdef TRACE
char *fmt_inst(uchar *pc);
void dump(void);
char *prim_name(value *p);
#endif

#ifdef i386
#define get_double(v) (* (double *) (v))
#define put_double(v, x) (* (double *) (v) = (x))
#define get_long(v) (* (longint *) (v))
#define put_long(v, x) (* (longint *) (v) = (x))
#else
double get_double(value *v);
void put_double(value *v, double x);
longint get_long(value *v);
void put_long(value *v, longint w);
#endif

double flo_conv(int);
double flo_convq(longint);


/* gc.c */

/* scratch_alloc -- allocate memory that will not be freed */
void *scratch_alloc(unsigned bytes, bool atomic);

/* gc_alloc -- allocate an object for the managed heap */
void *gc_alloc(value *desc, unsigned size, value *sp);

/* gc_collect -- run the garbage collector */
void gc_collect(value *xsp);

/* gc_alloc_size -- calculate allocated size of and object */
int gc_alloc_size(void *p);

/* gc_heap_size -- return size of heap */
int gc_heap_size(void);

extern bool gcflag;
void gc_init(void);
void gc_debug(char *flags);
void gc_dump(void);

/* debug.c */
#ifdef OBXDEB
extern bool one_shot;
extern bool intflag;

void debug_init(void);
void debug_message(char *fmt, ...);
void debug_break(value *cp, value *bp, uchar *pc, char *fmt, ...);
#endif

/* jit.c */
#ifdef JIT
void jit_compile(value *cp);
#endif

#endif

#ifdef ENABLE_JIT
/* On x86, each primitive re-initialises the FP unit, so that values
   left behind in registers by the caller do not cause stack overflow. */
#define FPINIT asm ("fninit")
#else
#define FPINIT
#endif

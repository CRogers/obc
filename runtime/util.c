/*
 * util.c
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
 * $Id: util.c 1230 2009-03-25 17:43:12Z mike $
 */

#include "config.h"
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "obcommon.h"
#include "util.h"
#include <assert.h>

EXTERN int dflag;

char *util_rcsid = "$Id: util.c 1230 2009-03-25 17:43:12Z mike $";

char *prog_name;

void error(char *msg, ...) {
     va_list va;

     va_start(va, msg);
     fprintf(stderr, "%s: ", err_file);
     vfprintf(stderr, msg, va);
     va_end(va);
     fprintf(stderr, "\n");

     status = 1;
}

void panic(char *msg, ...) {
     va_list va;
     bool bug = FALSE;

     if (*msg == '*') {
	  bug = TRUE; msg++;
     }

     fprintf(stderr, "%s: Fatal error -- ", progname);
     va_start(va, msg);
     vfprintf(stderr, msg, va);
     va_end(va);
     if (err_file != NULL)
       fprintf(stderr, " in %s", err_file);
     fprintf(stderr, "\n");
     if (bug)
	  fprintf(stderr, "Please report bugs to %s\n", PACKAGE_BUGREPORT);

     exit(2);
}

/* must_alloc -- malloc or die */
void *must_alloc(int n, char *why) {
     void *p;
#ifdef DEBUG
     if (dflag > 1) printf("Allocating %s as %d", why, n);
#endif
     p = malloc(n);
#ifdef DEBUG
     if (dflag > 1) printf(" at %p\n", p);
#endif
     if (p == NULL) panic("couldn't allocate space for %s", why);
     memset(p, 0, n);
     return p;
}

/* must_strdup -- strdup or die */
char *must_strdup(char *s) {
     char *p = must_alloc(strlen(s)+1, s);
     strcpy(p, s);
     return p;
}

/* must_realloc -- realloc or (you guessed it) */
void *must_realloc(void *p, int n0, int n, char *msg) {
#ifdef DEBUG
     if (dflag) {
	  printf("Growing %s at %p from %d to %d\n", msg, p, n0, n);
	  fflush(stdout);
     }
#endif
     p = realloc(p, n);
     if (p == NULL) panic("couldn't expand space for %s", msg);
     memset(((char *) p) + n0, 0, n-n0);
     return p;
}

void _buf_init(struct growbuf *b, int size, int margin, 
		       int elsize, char *name) {
     b->buf = must_alloc(size * elsize, name);
     b->loc = 0;
     b->size = size;
     b->margin = margin;
     b->elsize = elsize;
     b->name = name;
}

void _buf_grow(struct growbuf *b) {
     if (b == NULL) panic("*uninitialized growbuf");

     /* Ensure space for margin+1 items */
     if (b->loc > b->size - b->margin) {
	  int size1 = max(b->size * GROW, b->loc + b->margin);
	  b->buf = must_realloc(b->buf, b->size * b->elsize, 
				size1 * b->elsize, b->name);
	  b->size = size1;
     }
}

#define SIZE 10
#define PAGE 40000

void *pool_alloc(mempool *pool, int size) {
     void *result;

     assert(size < PAGE);

     if (pool->p_alloc + size > pool->p_pool[pool->p_current] + PAGE) {
	  pool->p_current++;
	  if (pool->p_current >= pool->p_npools) {
	       if (pool->p_npools >= pool->p_size) {
		    pool->p_pool = (unsigned char **) 
			 must_realloc(pool->p_pool,
				      pool->p_size * sizeof(void *),
				      2 * pool->p_size * sizeof(void *),
				      "pool table");
		    pool->p_size *= 2;
	       }
	       pool->p_pool[pool->p_npools++] = must_alloc(PAGE, "pools");
	  }
	  pool->p_alloc = pool->p_pool[pool->p_current];
     }

     result = (void *) pool->p_alloc;
     pool->p_alloc += size;
     return result;
}

void pool_reset(mempool *pool) {
     if (pool->p_pool == NULL) {
	  pool->p_pool = (unsigned char **)
	       must_alloc(SIZE * sizeof(void *), "pool table");
	  pool->p_pool[0] = must_alloc(PAGE, "pools");
	  pool->p_npools = 1; pool->p_size = SIZE;
     }

     pool->p_current = 0;
     pool->p_alloc = pool->p_pool[0];
}


int split_line(char *line, char **words) {
     int nwords = 0;
     char *s;

     s = line; 
     while (*s == ' ' || *s == '\t' || *s == '\r') s++;
     if (*s == '\n' || *s == '!' || *s == '\0') return 0;

     /* Set the words array */
     while (1) {
	  while (*s == ' ' || *s == '\t' || *s == '\r') s++;
	  if (*s == '\0') panic("line too long");
	  if (*s == '\n') break;
	  if (nwords == MAXWORDS) panic("too many words");
	  words[nwords++] = s;
	  while (! isspace((int) *s) && *s != '\0') s++;
	  if (*s == '\n') { *s = '\0'; break; }
	  if (*s == '\0') panic("line too long");
	  *s++ = '\0';
     }

     return nwords;
}

/* squidge -- change Oberon-style name into C identifier */
char *squidge(char *name) {
     static char buf[128];
     char *s, *t;

     for (s = name, t = buf; *s != '\0'; s++, t++)
	  *t = ((*s == '.' || *s == '%') ? '_' : *s);
     *t = '\0';

     return buf;
}

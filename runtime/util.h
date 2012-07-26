/*
 * util.h
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
 * $Id: util.h 1230 2009-03-25 17:43:12Z mike $
 */

EXTERN char *progname;
EXTERN char *err_file;
EXTERN int status;

void error(char *msg, ...);
void panic(char *msg, ...);
void *must_alloc(int n, char *msg);
void *must_realloc(void *p, int n0, int n, char *msg);
char *must_strdup(char *s);

/* Auto-grow buffers */

/*
To declare an autogrow buffer called A with size N and elements 
of type T, say:

     PRIVATE growdecl(A);
     #define A growbuf(A, T)
     #define N growsize(A)

Remarkably, the macro madness (which appears to define A recursively)
all works out fine.

To initialize the buffer:

     buf_init(A, init_size, margin, T, "the array A")

The message "Couldn't allocate space for the array A" will be printed
if allocation fails.

To check that at least |margin| elements remain unused:

     buf_grow(A) 
*/

#define GROW 1.5		/* Growth ratio when buffer full */

#define growdecl(b) struct growbuf _##b
#define growbuf(b, type) ((type *) _##b.buf)
#define growsize(b) _##b.loc
#define buf_init(b, size, margin, type, name) \
     _buf_init(&_##b, size, margin, sizeof(type), name)
#define buf_grow(b) _buf_grow(&_##b)

struct growbuf {
     void *buf;
     int loc, size, margin;
     int elsize;
     char *name;
};

void _buf_init(struct growbuf *b, int size, int margin, 
		      int elsize, char *name);
void _buf_grow(struct growbuf *b);


/* Memory pools */

typedef struct {
     unsigned char **p_pool;
     int p_current, p_npools, p_size;
     uchar *p_alloc;
} mempool;

void *pool_alloc(mempool *pool, int size);
void pool_reset(mempool *pool);


/* Splitting lines into words */

#define MAXWORDS 16
int split_line(char *line, char **words);

char *squidge(char *name);

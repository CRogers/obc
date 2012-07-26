/*
 * trace.c
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
 * $Id: trace.c 1646 2010-12-15 11:39:11Z mike $
 */

#define TRACE
#include "obx.h"
#include "keiko.h"

char *trace_rcsid = "$Id: trace.c 1646 2010-12-15 11:39:11Z mike $";

char *fmt_inst(uchar *pc) {
     uchar *args = pc;
     struct opcode *ip = &optable[*pc++];
     static char buf[80];
     char *p, *s = buf;

     if (ip->i_name == NULL) {
	  strcpy(buf, "UNKNOWN");
	  return buf;
     }

     s += sprintf(s, "%s", ip->i_name);

     for (p = ip->i_patt; *p != '\0'; p++) {
	  switch (*p) {
	  case '1': 
	       s += sprintf(s, " %d", get1(pc)); pc++; break;
	  case '2': 
	       s += sprintf(s, " %d", get2(pc)); pc += 2; break;
	  case 'R':
	       s += sprintf(s, " %d", get2(pc)+(args-imem)); pc += 2; break;
	  case 'S':
	       s += sprintf(s, " %d", get1(pc)+(args-imem)); pc += 1; break;
	  case 'N':
	       s += sprintf(s, " %d", ip->i_arg); break;
	  default:
	       s += sprintf(s, " ?%c?", *p);
	  }
     }

     return buf;
}

void dump(void) {
     int i, k;

     for (k = 0; k < nprocs; k++) {
	  proc p = proctab[k];
	  value *cp = p->p_addr;
	  uchar *pc, *limit;

	  if (cp[CP_PRIM].z != interp) continue;
	  
	  pc = cp[CP_CODE].x; limit = pc + cp[CP_SIZE].i;

	  printf("Procedure %s:\n", proctab[k]->p_name);
	  while (pc < limit) {
	       int op = *pc;
	       uchar *pc1 = pc + optable[op].i_len;

	       printf("%6d: %-30s", pc-imem, fmt_inst(pc));
	       while (pc < pc1) printf(" %d", *pc++);
	       printf("\n");

	       if (op == K_JCASE_1) {
		    int n = pc[-1];
		    for (i = 0; i < n; i++) {
			 printf("%6d:   CASEL %-22d %d %d\n", pc-imem, 
				get2(pc)+(pc-imem), pc[0], pc[1]);
			 pc += 2;
		    }
	       }

#ifdef SPECIALS
 	       if (op == K_CASEJUMP_1) {
 		    int n = get2(pc-1);
 		    for (i = 0; i < n; i++) {
 			 printf("%6d:   CASEV %d %d\n", pc-imem,
 				get2(pc), get2(pc+2)+(pc-imem));
 			 pc += 4;
 		    }
 	       }
#endif
	  }
     }
}

char *prim_name(value *p) {
     primitive *z = p[0].z;
     int i;

     for (i = 0; primtab[i] != NULL; i++)
	  if (i != 1 && primtab[i] == z)
	       return primname[i];

     if (p[1].x != NULL) return (char *) p[1].x;

     return "(unknown)";
}

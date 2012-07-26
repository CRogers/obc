/*
 * obc.c
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
 * $Id: obc.c 1669 2011-02-01 23:52:29Z mike $
 */

#include "wrap.h"

static UNUSED char *rcsid = 
     "$Id: obc.c 1669 2011-02-01 23:52:29Z mike $";

#define COMPILER "obc1.exe"
#define LINKER "oblink.exe"
#define RUNTIME "obx.exe"
#define RUNTIMEJ "obxj.exe"
#define SRCEXT 'm'
#define OBJEXT 'k'

char *runtime = RUNTIMEJ;

int has_ext(char *fname, char ext)
{
    int n = strlen(fname);
    return fname[n-2] == '.' && fname[n-1] == ext;
}

char *basename(char *srcname)
{
     char *p = &srcname[strlen(srcname)];

     while (p > srcname && p[-1] != '\\' && p[-1] != '/' && p[-1] != ':')
	  p--;

     return p;
}

char *changext(char *srcname, char ext)
{
     static char buf[MAX];

     strcpy(buf, srcname);
     buf[strlen(buf)-1] = ext;
     return buf;
}

/* addexe -- add .exe extension if no extension is present */
char *addexe(char *name)
{
     static char buf[MAX];

     if (strchr(basename(name), '.') != NULL)
	  return name;

     strcpy(buf, name);
     strcat(buf, ".exe");
     return buf;
}

#define NBUF 65536

int append_file(char *fname, int ofd)
{
     int ifd, n;
     static char buf[NBUF];

     ifd = open(fname, O_RDONLY|O_BINARY, 0);
     if (ifd < 0) {
	  perror(fname);
	  return ifd;
     }

     for (;;) {
	  n = read(ifd, buf, NBUF);
	  if (n == 0) break;
	  write(ofd, buf, n);
     }

     close(ifd);
     return 0;
}

int vflag = 0, cflag = 0;
char *lscript = "lscript";
int n_sws, n_lsws;
char *sws[MAXARGS], *lsws[MAXARGS];

int compile(char *src, char *obj)
{
     char cmdbuf[MAX];
     int i, status;

     sprintf(cmdbuf, "%s\\%s", obclib, COMPILER);
     arg(cmdbuf);
     for (i = 0; i < n_sws; i++) arg(sws[i]);
     arg("-pl"); arg("-g"); arg("-I"); arg(obclib); arg(src);
     status = redir_command(cmdbuf, vflag, obj);
     if (status != 0) unlink(obj);
     return status;
}

static char *linker_tmp;

void rm_tmp(void)
{
     if (vflag) fprintf(stderr, "Removing %s\n", linker_tmp);
     unlink(linker_tmp);
}

int linkit(int n_objs, char *objfile[], char *exefile)
{
     char cmdbuf[MAX];
     int fd, i, status = 0;

     /* I must be the 2^20'th person to fall over the broken
	tmpnam() in MINGW */
     char *tempdir = getenv("TEMP");
     if (tempdir == NULL) tempdir = ".";
     linker_tmp = tempnam(tempdir, "obtmp");
     atexit(rm_tmp);

     /* Run the linker */
     sprintf(cmdbuf, "%s\\%s", obclib, LINKER); 
     arg(cmdbuf); arg("-L"); arg(obclib);
     for (i = 0; i < n_lsws; i++) arg(lsws[i]);
     for (i = 0; i < n_objs; i++) arg(objfile[i]);
     arg("-pl"); arg("-g"); arg("-o"); arg(linker_tmp);
     status = command(cmdbuf, vflag);
     if (status != 0) return status;

     /* Concatenate linker output with runtime */
     sprintf(cmdbuf, "%s\\%s", obclib, runtime);
     if (vflag) 
	  fprintf(stderr, "Concatenating %s + %s --> %s\n", 
		  cmdbuf, linker_tmp, exefile);

     fd = open(exefile, O_WRONLY|O_CREAT|O_TRUNC|O_BINARY, S_IREAD|S_IWRITE);
     if (fd < 0) {
	  perror(exefile);
	  return 2;
     }

     status = append_file(cmdbuf, fd);
     if (status == 0)
	status = append_file(linker_tmp, fd);
     close(fd);
     if (status != 0) unlink(exefile);
     return status;
}

void versions(void)
{
     char **s, cmdbuf[MAX];
     static char *progs[] = { COMPILER, LINKER, RUNTIME, NULL };
     
     printf("Oxford Oberon-2 compiler driver version %s\n", PACKAGE_VERSION);
     for (s = progs; *s != NULL; s++) {
	  sprintf(cmdbuf, "%s\\%s", obclib, *s);
	  arg(cmdbuf); arg("-v");
	  command(cmdbuf, 0);
     }
}

void usage(void)
{
#define p(str) fprintf(stderr, "%s\n", str);
     p("Usage: obc [flag ...] file ...");
     p("");
     p("  -O0     Turn off peephole optimiser");
     p("  -O      Turn on peephole optimiser (default)");
     p("  -b      Disable runtime checks");
     p("  -g      Output debugging symbols");
     p("  -v      Print compiling and linking commands");
     p("  -w      Turn off warnings");
     p("  -x      Enable language extensions");
     p("  -pl     Output line numbers for profiling or debugging");
     p("  -I dir  Add dir as search directory for imported modules");
     p("  -rsb    Keywords and built-ins are in lower case" );
     p("  -c      Compile only; omit linking step");
     p("  -o file Set output file for linking");
     p("  -s      Strip symbol table in linker output");
     p("  -j0     Disable JIT translator at runtime");
     p("  -k n    Set runtime stack size");
     p("");
     p("  *.m     Oberon source file to be compiled");
     p("  *.k     Bytecode file for linking");
     p("  *.c     File of primitives coded in C");
     p("  *.o     File of object code for primitives");
     exit(2);
}

int main(int argc, char *argv[])
{
     int n_src = 0, n_obj = 0, lflag = 1, status = 0, st, i;
     static char *srcs[MAXARGS], *objs[MAXARGS];
     char *aout = "aout.exe";

     check_path(COMPILER);

     if (argc <= 1) usage();

     for (i = 1; i < argc; i++) {
	  char *s = argv[i];

#define m(str) (strcmp(s, str) == 0)

	  if (m("-v"))
	       vflag = 1;
	  else if (m("-c"))
	       lflag = 0;
	  else if (m("-o")) {
	       if (++i >= argc) usage();
	       aout = argv[i];
	  }
	  else if (m("-s"))
	       lsws[n_lsws++] = "-s";
	  else if (m("-b")) {
	       sws[n_sws++] = "-b";
	       lscript = "lscript-b";
	  }
	  else if (m("-pl") || m("-g")) {
	       /* Now the default */
	  }
	  else if (m("-j0"))
	       runtime = RUNTIME;
	  else if (m("-O0") || m("-O") || m("-w") 
		   || m("-x") || m("-rsb"))
	       sws[n_sws++] = s;
	  else if (m("-I")) {
	       if (++i >= argc) usage();
	       sws[n_sws++] = "-I";
	       sws[n_sws++] = argv[i];
	  }
	  else if (m("-k")) {
	       if (++i >= argc) usage();
	       lsws[n_lsws++] = "-k";
	       lsws[n_lsws++] = argv[i];
	  }	       
	  else if (s[0] == '-')
	       usage();
	  else if (has_ext(s, SRCEXT)) {
	       srcs[n_src++] = s;
	       objs[n_obj++] = strdup(changext(basename(s), OBJEXT));
	  }
	  else if (has_ext(s, OBJEXT))
	       objs[n_obj++] = s;
	  else
	       usage();
     }

     if (vflag) versions();

     if (n_obj == 0) {
	  if (vflag) exit(0); else usage();
     }

     for (i = 0; i < n_src; i++) {
	  st = compile(srcs[i], changext(basename(srcs[i]), OBJEXT));
	  if (status == 0) status = st;
     }

     if (lflag && status == 0)
	  status = linkit(n_obj, objs, addexe(aout));

     return status;
}

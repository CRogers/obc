MODULE tKnuth;

(* Solve the recurrence f(n) = f(n-1) + f(floor(n/2)), f(0) = 1. *)

IMPORT Out;

CONST N = 10; M = 1000000000;

TYPE bignum = ARRAY N OF INTEGER;

PROCEDURE Normalize(VAR a: bignum);
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO N-2 DO
    a[i+1] := a[i+1] + a[i] DIV M;
    a[i] := a[i] MOD M
  END
END Normalize;

PROCEDURE Set(VAR a: bignum; x: INTEGER);
  VAR i: INTEGER;
BEGIN
  a[0] := x;
  FOR i := 1 TO N-1 DO a[i] := 0 END;
  Normalize(a)
END Set;

PROCEDURE Add(VAR a1: bignum; a2: bignum);
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO N-1 DO a1[i] := a1[i] + a2[i] END;
  Normalize(a1)
END Add;

PROCEDURE PrintPiece(x: INTEGER);
  VAR m: INTEGER;
BEGIN
  m := M;
  WHILE m > 1 DO
    m := m DIV 10;
    Out.Int(x DIV m, 0);
    x := x MOD m
  END
END PrintPiece;

PROCEDURE Print(VAR a: bignum);
  VAR i: INTEGER;
BEGIN
  i := N-1;
  WHILE (i > 0) & (a[i] = 0) DO i := i-1 END;
  Out.Int(a[i], 0); i := i-1;
  WHILE i >= 0 DO PrintPiece(a[i]); i := i-1 END
END Print;

PROCEDURE Calc(n: INTEGER; VAR ans: bignum);
  CONST K = 20;
  VAR 
    i, j, k: INTEGER;
    arg: ARRAY K OF INTEGER;
    val: ARRAY K OF bignum;
BEGIN
  FOR j := 0 TO K-1 DO arg[j] := 0; Set(val[j], 1) END;

  (* Invariant: arg[j+1] = arg[j] DIV 2, val[j] = f(arg[j]) *)

  FOR i := 1 TO n DO
    j := 0; k := i;
    WHILE k > arg[j] DO k := k DIV 2; j := j + 1 END;
    WHILE j > 0 DO
      j := j - 1;
      INC(arg[j]);
      Add(val[j], val[j+1])
    END
  END;

  ans := val[0]
END Calc;

VAR ans: bignum;

BEGIN
  Calc(10000, ans);
  Print(ans); Out.Ln
END tKnuth.

(*<<
214454008193526428202
>>*)

(*[[
!! SYMFILE #tKnuth STAMP #tKnuth.%main 1
!! END STAMP
!! 
MODULE tKnuth STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tKnuth.Normalize 1 4 0x00100001
! PROCEDURE Normalize(VAR a: bignum);
!   FOR i := 0 TO N-2 DO
CONST 0
STLW -4
JUMP 2
LABEL 1
!     a[i+1] := a[i+1] + a[i] DIV M;
LDLW 12
LDLW -4
INC
CONST 10
BOUND 15
LDIW
LDLW 12
LDLW -4
CONST 10
BOUND 15
LDIW
CONST 1000000000
DIV
PLUS
LDLW 12
LDLW -4
INC
CONST 10
BOUND 15
STIW
!     a[i] := a[i] MOD M
LDLW 12
LDLW -4
CONST 10
BOUND 16
LDIW
CONST 1000000000
MOD
LDLW 12
LDLW -4
CONST 10
BOUND 16
STIW
!   FOR i := 0 TO N-2 DO
INCL -4
LABEL 2
LDLW -4
CONST 8
JLEQ 1
RETURN
END

PROC tKnuth.Set 1 4 0x00100001
! PROCEDURE Set(VAR a: bignum; x: INTEGER);
!   a[0] := x;
LDLW 16
LDLW 12
STOREW
!   FOR i := 1 TO N-1 DO a[i] := 0 END;
CONST 1
STLW -4
JUMP 4
LABEL 3
CONST 0
LDLW 12
LDLW -4
CONST 10
BOUND 24
STIW
INCL -4
LABEL 4
LDLW -4
CONST 9
JLEQ 3
!   Normalize(a)
LDLW 12
GLOBAL tKnuth.Normalize
CALL 1
RETURN
END

PROC tKnuth.Add 11 4 0x00100001
! PROCEDURE Add(VAR a1: bignum; a2: bignum);
LOCAL -44
LDLW 16
CONST 40
FIXCOPY
!   FOR i := 0 TO N-1 DO a1[i] := a1[i] + a2[i] END;
CONST 0
STLW -4
JUMP 6
LABEL 5
LDLW 12
LDLW -4
CONST 10
BOUND 31
LDIW
LOCAL -44
LDLW -4
CONST 10
BOUND 31
LDIW
PLUS
LDLW 12
LDLW -4
CONST 10
BOUND 31
STIW
INCL -4
LABEL 6
LDLW -4
CONST 9
JLEQ 5
!   Normalize(a1)
LDLW 12
GLOBAL tKnuth.Normalize
CALL 1
RETURN
END

PROC tKnuth.PrintPiece 1 4 0
! PROCEDURE PrintPiece(x: INTEGER);
!   m := M;
CONST 1000000000
STLW -4
JUMP 8
LABEL 7
!     m := m DIV 10;
LDLW -4
CONST 10
DIV
STLW -4
!     Out.Int(x DIV m, 0);
CONST 0
LDLW 12
LDLW -4
ZCHECK 41
DIV
GLOBAL Out.Int
CALL 2
!     x := x MOD m
LDLW 12
LDLW -4
ZCHECK 42
MOD
STLW 12
LABEL 8
!   WHILE m > 1 DO
LDLW -4
CONST 1
JGT 7
RETURN
END

PROC tKnuth.Print 1 4 0x00100001
! PROCEDURE Print(VAR a: bignum);
!   i := N-1;
CONST 9
STLW -4
JUMP 10
LABEL 9
DECL -4
LABEL 10
!   WHILE (i > 0) & (a[i] = 0) DO i := i-1 END;
LDLW -4
JLEQZ 11
LDLW 12
LDLW -4
CONST 10
BOUND 50
LDIW
JEQZ 9
LABEL 11
!   Out.Int(a[i], 0); i := i-1;
CONST 0
LDLW 12
LDLW -4
CONST 10
BOUND 51
LDIW
GLOBAL Out.Int
CALL 2
DECL -4
JUMP 13
LABEL 12
LDLW 12
LDLW -4
CONST 10
BOUND 52
LDIW
GLOBAL tKnuth.PrintPiece
CALL 1
DECL -4
LABEL 13
!   WHILE i >= 0 DO PrintPiece(a[i]); i := i-1 END
LDLW -4
JGEQZ 12
RETURN
END

PROC tKnuth.Calc 224 4 0x00200001
! PROCEDURE Calc(n: INTEGER; VAR ans: bignum);
!   FOR j := 0 TO K-1 DO arg[j] := 0; Set(val[j], 1) END;
CONST 0
STLW -8
JUMP 15
LABEL 14
CONST 0
LOCAL -92
LDLW -8
CONST 20
BOUND 62
STIW
CONST 1
LOCAL -892
LDLW -8
CONST 20
BOUND 62
CONST 40
TIMES
PLUSA
GLOBAL tKnuth.Set
CALL 2
INCL -8
LABEL 15
LDLW -8
CONST 19
JLEQ 14
!   FOR i := 1 TO n DO
LDLW 12
STLW -896
CONST 1
STLW -4
JUMP 17
LABEL 16
!     j := 0; k := i;
CONST 0
STLW -8
LDLW -4
STLW -12
JUMP 19
LABEL 18
LDLW -12
CONST 2
DIV
STLW -12
INCL -8
LABEL 19
!     WHILE k > arg[j] DO k := k DIV 2; j := j + 1 END;
LDLW -12
LOCAL -92
LDLW -8
CONST 20
BOUND 68
LDIW
JGT 18
JUMP 21
LABEL 20
!       j := j - 1;
DECL -8
!       INC(arg[j]);
LOCAL -92
LDLW -8
CONST 20
BOUND 71
INDEXW
DUP 0
LOADW
INC
SWAP
STOREW
!       Add(val[j], val[j+1])
LOCAL -892
LDLW -8
INC
CONST 20
BOUND 72
CONST 40
TIMES
PLUSA
LOCAL -892
LDLW -8
CONST 20
BOUND 72
CONST 40
TIMES
PLUSA
GLOBAL tKnuth.Add
CALL 2
LABEL 21
!     WHILE j > 0 DO
LDLW -8
JGTZ 20
!   FOR i := 1 TO n DO
INCL -4
LABEL 17
LDLW -4
LDLW -896
JLEQ 16
!   ans := val[0]
LDLW 16
LOCAL -892
CONST 40
FIXCOPY
RETURN
END

PROC tKnuth.%main 0 4 0
!   Calc(10000, ans);
GLOBAL tKnuth.ans
CONST 10000
GLOBAL tKnuth.Calc
CALL 2
!   Print(ans); Out.Ln
GLOBAL tKnuth.ans
GLOBAL tKnuth.Print
CALL 1
GLOBAL Out.Ln
CALL 0
RETURN
END

! Global variables
GLOVAR tKnuth.ans 40

! End of file
]]*)

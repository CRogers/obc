MODULE tPascal;

(*<<
1
1 1
1 2 1
1 3 3 1
1 4 6 4 1
1 5 10 10 5 1
1 6 15 20 15 6 1
1 7 21 35 35 21 7 1
1 8 28 56 70 56 28 8 1
1 9 36 84 126 126 84 36 9 1
>>*)

IMPORT Out;

CONST n = 10;

PROCEDURE pascal2();
  VAR i, j: INTEGER;
  VAR a: POINTER TO ARRAY n OF ARRAY n+1 OF INTEGER;
BEGIN
  NEW(a);
  i := 0;
  WHILE i < n DO
    a[i, 0] := 1; j := 1;
    Out.Int(a[i, 0], 0);
    WHILE j <= i DO
      a[i, j] := a[i-1, j-1] + a[i-1, j];
      Out.Char(' '); Out.Int(a[i, j], 0);
      j := j+1
    END;
    a[i, i+1] := 0;
    Out.Ln;
    i := i+1
  END
END pascal2;

BEGIN
  pascal2()
END tPascal.

(*[[
!! SYMFILE #tPascal STAMP #tPascal.%main 1
!! END STAMP
!! 
MODULE tPascal STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tPascal.pascal2 3 5 0x00004001
! PROCEDURE pascal2();
!   NEW(a);
CONST 440
CONST 0
LOCAL -12
GLOBAL NEW
CALL 3
!   i := 0;
CONST 0
STLW -4
JUMP 2
LABEL 1
!     a[i, 0] := 1; j := 1;
CONST 1
LDLW -12
NCHECK 27
LDLW -4
CONST 10
BOUND 27
CONST 11
TIMES
STIW
CONST 1
STLW -8
!     Out.Int(a[i, 0], 0);
CONST 0
LDLW -12
NCHECK 28
LDLW -4
CONST 10
BOUND 28
CONST 11
TIMES
LDIW
GLOBAL Out.Int
CALL 2
JUMP 4
LABEL 3
!       a[i, j] := a[i-1, j-1] + a[i-1, j];
LDLW -12
NCHECK 30
LDLW -4
DEC
CONST 10
BOUND 30
CONST 11
TIMES
LDLW -8
DEC
CONST 11
BOUND 30
PLUS
LDIW
LDLW -12
NCHECK 30
LDLW -4
DEC
CONST 10
BOUND 30
CONST 11
TIMES
LDLW -8
CONST 11
BOUND 30
PLUS
LDIW
PLUS
LDLW -12
NCHECK 30
LDLW -4
CONST 10
BOUND 30
CONST 11
TIMES
LDLW -8
CONST 11
BOUND 30
PLUS
STIW
!       Out.Char(' '); Out.Int(a[i, j], 0);
CONST 32
ALIGNC
GLOBAL Out.Char
CALL 1
CONST 0
LDLW -12
NCHECK 31
LDLW -4
CONST 10
BOUND 31
CONST 11
TIMES
LDLW -8
CONST 11
BOUND 31
PLUS
LDIW
GLOBAL Out.Int
CALL 2
!       j := j+1
INCL -8
LABEL 4
!     WHILE j <= i DO
LDLW -8
LDLW -4
JLEQ 3
!     a[i, i+1] := 0;
CONST 0
LDLW -12
NCHECK 34
LDLW -4
CONST 10
BOUND 34
CONST 11
TIMES
LDLW -4
INC
CONST 11
BOUND 34
PLUS
STIW
!     Out.Ln;
GLOBAL Out.Ln
CALL 0
!     i := i+1
INCL -4
LABEL 2
!   WHILE i < n DO
LDLW -4
CONST 10
JLT 1
RETURN
END

PROC tPascal.%main 0 5 0
!   pascal2()
GLOBAL tPascal.pascal2
CALL 0
RETURN
END

! End of file
]]*)

$Id: tPascal.m 1678 2011-03-15 20:27:21Z mike $

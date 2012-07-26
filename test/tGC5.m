MODULE tGC5;

IMPORT Out, GC;

CONST N = 1000;

CONST a = 3141592; b = 1618033; M = 2718281;

VAR seed: INTEGER;

PROCEDURE Random(N: INTEGER): INTEGER;
BEGIN
  seed := (seed * a + b) MOD M;
  RETURN seed MOD N
END Random;

TYPE tree = POINTER TO cell;
  cell = RECORD key, value: INTEGER; left, right: tree END;

PROCEDURE Size(t: tree): INTEGER;
BEGIN
  IF t = NIL THEN
    RETURN 0
  ELSE
    RETURN t.value + Size(t.left) + Size(t.right)
  END
END Size;

PROCEDURE Cons(key, value: INTEGER; left, right: tree): tree;
  VAR t: tree;
BEGIN
  NEW(t);
  t.key := key; t.value := value;
  t.left := left; t.right := right;
  RETURN t
END Cons;

PROCEDURE Increment(key: INTEGER; t: tree): tree;
BEGIN
  IF t = NIL THEN
    RETURN Cons(key, 1, NIL, NIL)
  ELSIF key = t.key THEN
    RETURN Cons(key, t.value+1, t.left, t.right)
  ELSIF key < t.key THEN
    RETURN Cons(t.key, t.value, Increment(key, t.left), t.right)
  ELSE
    RETURN Cons(t.key, t.value, t.left, Increment(key, t.right))
  END
END Increment;
    
PROCEDURE Ordered(t: tree; lo, hi: INTEGER): BOOLEAN;
BEGIN
  IF t = NIL THEN
    RETURN TRUE
  ELSE
    RETURN (lo <= t.key) & (t.key < hi) 
	& Ordered(t.left, lo, t.key)
	& Ordered(t.right, t.key+1, hi)
  END
END Ordered;

VAR 
  i: INTEGER;
  t: tree;

CONST K = 50000;

BEGIN
  GC.Debug("s");

  t := NIL;
  FOR i := 1 TO K DO
    t := Increment(Random(100), t)
  END;
  Out.Int(Size(t), 0); Out.Ln;
  IF Ordered(t, 0, 100) THEN Out.String("ordered"); Out.Ln END;
  Out.Int(GC.HeapSize(), 0); Out.Ln
END tGC5.

(*<<
50000
ordered
2097152
>>*)

(*[[
!! SYMFILE #tGC5 STAMP #tGC5.%main 1
!! END STAMP
!! 
MODULE tGC5 STAMP 0
IMPORT Out STAMP
IMPORT GC STAMP
ENDHDR

PROC tGC5.Random 0 2 0
! PROCEDURE Random(N: INTEGER): INTEGER;
!   seed := (seed * a + b) MOD M;
LDGW tGC5.seed
CONST 3141592
TIMES
CONST 1618033
PLUS
CONST 2718281
MOD
STGW tGC5.seed
!   RETURN seed MOD N
LDGW tGC5.seed
LDLW 12
ZCHECK 14
MOD
RETURNW
END

PROC tGC5.Size 0 3 0x00100001
! PROCEDURE Size(t: tree): INTEGER;
!   IF t = NIL THEN
LDLW 12
JNEQZ 4
!     RETURN 0
CONST 0
RETURNW
LABEL 4
!     RETURN t.value + Size(t.left) + Size(t.right)
LDLW 12
NCHECK 25
LDNW 4
LDLW 12
NCHECK 25
LDNW 8
GLOBAL tGC5.Size
CALLW 1
PLUS
LDLW 12
NCHECK 25
LDNW 12
GLOBAL tGC5.Size
CALLW 1
PLUS
RETURNW
END

PROC tGC5.Cons 1 4 0x00c10001
! PROCEDURE Cons(key, value: INTEGER; left, right: tree): tree;
!   NEW(t);
CONST 16
GLOBAL tGC5.cell
LOCAL -4
GLOBAL NEW
CALL 3
!   t.key := key; t.value := value;
LDLW 12
LDLW -4
NCHECK 33
STOREW
LDLW 16
LDLW -4
NCHECK 33
STNW 4
!   t.left := left; t.right := right;
LDLW 20
LDLW -4
NCHECK 34
STNW 8
LDLW 24
LDLW -4
NCHECK 34
STNW 12
!   RETURN t
LDLW -4
RETURNW
END

PROC tGC5.Increment 0 5 0x00200001
! PROCEDURE Increment(key: INTEGER; t: tree): tree;
!   IF t = NIL THEN
LDLW 16
JNEQZ 6
!     RETURN Cons(key, 1, NIL, NIL)
CONST 0
CONST 0
CONST 1
LDLW 12
GLOBAL tGC5.Cons
CALLW 4
RETURNW
LABEL 6
!   ELSIF key = t.key THEN
LDLW 12
LDLW 16
NCHECK 42
LOADW
JNEQ 7
!     RETURN Cons(key, t.value+1, t.left, t.right)
LDLW 16
NCHECK 43
LDNW 12
LDLW 16
NCHECK 43
LDNW 8
LDLW 16
NCHECK 43
LDNW 4
INC
LDLW 12
GLOBAL tGC5.Cons
CALLW 4
RETURNW
LABEL 7
!   ELSIF key < t.key THEN
LDLW 12
LDLW 16
NCHECK 44
LOADW
JGEQ 8
!     RETURN Cons(t.key, t.value, Increment(key, t.left), t.right)
LDLW 16
NCHECK 45
LDNW 12
LDLW 16
NCHECK 45
LDNW 8
LDLW 12
GLOBAL tGC5.Increment
STKMAP 0x00000009
CALLW 2
LDLW 16
NCHECK 45
LDNW 4
LDLW 16
NCHECK 45
LOADW
GLOBAL tGC5.Cons
CALLW 4
RETURNW
LABEL 8
!     RETURN Cons(t.key, t.value, t.left, Increment(key, t.right))
LDLW 16
NCHECK 47
LDNW 12
LDLW 12
GLOBAL tGC5.Increment
CALLW 2
LDLW 16
NCHECK 47
LDNW 8
LDLW 16
NCHECK 47
LDNW 4
LDLW 16
NCHECK 47
LOADW
GLOBAL tGC5.Cons
CALLW 4
RETURNW
END

PROC tGC5.Ordered 0 5 0x00100001
! PROCEDURE Ordered(t: tree; lo, hi: INTEGER): BOOLEAN;
!   IF t = NIL THEN
LDLW 12
JNEQZ 11
!     RETURN TRUE
CONST 1
RETURNW
LABEL 11
!     RETURN (lo <= t.key) & (t.key < hi) 
LDLW 16
LDLW 12
NCHECK 56
LOADW
JGT 14
LDLW 12
NCHECK 56
LOADW
LDLW 20
JGEQ 14
! 	& Ordered(t.left, lo, t.key)
LDLW 12
NCHECK 57
LOADW
LDLW 16
LDLW 12
NCHECK 57
LDNW 8
GLOBAL tGC5.Ordered
CALLW 3
JUMPT 12
LABEL 14
CONST 0
RETURNW
LABEL 12
! 	& Ordered(t.right, t.key+1, hi)
LDLW 20
LDLW 12
NCHECK 58
LOADW
INC
LDLW 12
NCHECK 58
LDNW 12
GLOBAL tGC5.Ordered
CALLW 3
RETURNW
END

PROC tGC5.%main 0 5 0
!   GC.Debug("s");
CONST 2
GLOBAL tGC5.%2
GLOBAL GC.Debug
CALL 2
!   t := NIL;
CONST 0
STGW tGC5.t
!   FOR i := 1 TO K DO
CONST 1
STGW tGC5.i
JUMP 16
LABEL 15
!     t := Increment(Random(100), t)
LDGW tGC5.t
CONST 100
GLOBAL tGC5.Random
STKMAP 0x00000005
CALLW 1
GLOBAL tGC5.Increment
CALLW 2
STGW tGC5.t
!   FOR i := 1 TO K DO
LDGW tGC5.i
INC
STGW tGC5.i
LABEL 16
LDGW tGC5.i
CONST 50000
JLEQ 15
!   Out.Int(Size(t), 0); Out.Ln;
CONST 0
LDGW tGC5.t
GLOBAL tGC5.Size
CALLW 1
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
!   IF Ordered(t, 0, 100) THEN Out.String("ordered"); Out.Ln END;
CONST 100
CONST 0
LDGW tGC5.t
GLOBAL tGC5.Ordered
CALLW 3
JUMPF 19
CONST 8
GLOBAL tGC5.%1
GLOBAL Out.String
CALL 2
GLOBAL Out.Ln
CALL 0
LABEL 19
!   Out.Int(GC.HeapSize(), 0); Out.Ln
CONST 0
GLOBAL GC.HeapSize
CALLW 0
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
RETURN
END

! Global variables
GLOVAR tGC5.seed 4
GLOVAR tGC5.i 4
GLOVAR tGC5.t 4

! Pointer map
DEFINE tGC5.%gcmap
WORD GC_BASE
WORD tGC5.t
WORD 0
WORD GC_END

! String "ordered"
DEFINE tGC5.%1
STRING 6F72646572656400

! String "s"
DEFINE tGC5.%2
STRING 7300

! Descriptor for cell
DEFINE tGC5.cell
WORD 0x00000019
WORD 0
WORD tGC5.cell.%anc

DEFINE tGC5.cell.%anc
WORD tGC5.cell

! End of file
]]*)

$Id: tGC5.m 1678 2011-03-15 20:27:21Z mike $

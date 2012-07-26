MODULE tQuicksort;

IMPORT Random, Out;

CONST N = 60;

TYPE vec = ARRAY N OF INTEGER;

PROCEDURE Swap(VAR x, y: INTEGER);
  VAR t: INTEGER;
BEGIN
  t := x; x := y; y := t
END Swap;

PROCEDURE Partition(VAR u: vec; a, b: INTEGER): INTEGER;
  VAR i, j, pivot: INTEGER;
BEGIN
  i := a+1; j := b; pivot := u[a];
  WHILE i < j DO
    WHILE (i < j) & (u[i] < pivot) DO i := i+1 END;
    WHILE (i < j) & (u[j-1] > pivot) DO j := j-1 END;
    IF i < j THEN 
      Swap(u[i], u[j-1]); 
      i := i+1; j := j-1 
    END
  END;
  (* |u[a+1..i) <= pivot| and |u[j..b) >= pivot| and |j <= i| *)
  Swap(u[a], u[i-1]);
  RETURN i-1
END Partition;

(* Quicksort -- sort |u[a..b)| *)
PROCEDURE Quicksort(VAR u: vec; a, b: INTEGER);
  VAR k: INTEGER;
BEGIN
  IF b - a > 1 THEN
    k := Partition(u, a, b);
    Quicksort(u, a, k);
    Quicksort(u, k+1, b);
  END
END Quicksort;

PROCEDURE Sort(VAR u: vec);
BEGIN
  Quicksort(u, 0, N)
END Sort;

PROCEDURE Test;
  VAR i: INTEGER; a: vec;
BEGIN
  FOR i := 0 TO N-1 DO a[i] := Random.Roll(10) END;
  FOR i := 0 TO N-1 DO Out.Int(a[i], 0) END; Out.Ln;
  Sort(a);
  FOR i := 0 TO N-1 DO Out.Int(a[i], 0) END; Out.Ln
END Test;

BEGIN
  Test
END tQuicksort.

(*<<
119978306115907675004286403777538494004382883317447914012890
000000000111111122233333344444444555666777777778888888999999
>>*)

(*[[
!! SYMFILE #tQuicksort STAMP #tQuicksort.%main 1
!! END STAMP
!! 
MODULE tQuicksort STAMP 0
IMPORT Random STAMP
IMPORT Out STAMP
ENDHDR

PROC tQuicksort.Swap 1 2 0x00300001
! PROCEDURE Swap(VAR x, y: INTEGER);
!   t := x; x := y; y := t
LDLW 12
LOADW
STLW -4
LDLW 16
LOADW
LDLW 12
STOREW
LDLW -4
LDLW 16
STOREW
RETURN
END

PROC tQuicksort.Partition 3 4 0x00100001
! PROCEDURE Partition(VAR u: vec; a, b: INTEGER): INTEGER;
!   i := a+1; j := b; pivot := u[a];
LDLW 16
INC
STLW -4
LDLW 20
STLW -8
LDLW 12
LDLW 16
CONST 60
BOUND 18
LDIW
STLW -12
JUMP 10
LABEL 3
INCL -4
LABEL 4
!     WHILE (i < j) & (u[i] < pivot) DO i := i+1 END;
LDLW -4
LDLW -8
JGEQ 7
LDLW 12
LDLW -4
CONST 60
BOUND 20
LDIW
LDLW -12
JLT 3
JUMP 7
LABEL 6
DECL -8
LABEL 7
!     WHILE (i < j) & (u[j-1] > pivot) DO j := j-1 END;
LDLW -4
LDLW -8
JGEQ 8
LDLW 12
LDLW -8
DEC
CONST 60
BOUND 21
LDIW
LDLW -12
JGT 6
LABEL 8
!     IF i < j THEN 
LDLW -4
LDLW -8
JGEQ 10
!       Swap(u[i], u[j-1]); 
LDLW 12
LDLW -8
DEC
CONST 60
BOUND 23
INDEXW
LDLW 12
LDLW -4
CONST 60
BOUND 23
INDEXW
GLOBAL tQuicksort.Swap
CALL 2
!       i := i+1; j := j-1 
INCL -4
DECL -8
LABEL 10
!   WHILE i < j DO
LDLW -4
LDLW -8
JLT 4
!   Swap(u[a], u[i-1]);
LDLW 12
LDLW -4
DEC
CONST 60
BOUND 28
INDEXW
LDLW 12
LDLW 16
CONST 60
BOUND 28
INDEXW
GLOBAL tQuicksort.Swap
CALL 2
!   RETURN i-1
LDLW -4
DEC
RETURNW
END

PROC tQuicksort.Quicksort 1 4 0x00100001
! PROCEDURE Quicksort(VAR u: vec; a, b: INTEGER);
!   IF b - a > 1 THEN
LDLW 20
LDLW 16
MINUS
CONST 1
JLEQ 12
!     k := Partition(u, a, b);
LDLW 20
LDLW 16
LDLW 12
GLOBAL tQuicksort.Partition
CALLW 3
STLW -4
!     Quicksort(u, a, k);
LDLW -4
LDLW 16
LDLW 12
GLOBAL tQuicksort.Quicksort
CALL 3
!     Quicksort(u, k+1, b);
LDLW 20
LDLW -4
INC
LDLW 12
GLOBAL tQuicksort.Quicksort
CALL 3
LABEL 12
RETURN
END

PROC tQuicksort.Sort 0 4 0x00100001
! PROCEDURE Sort(VAR u: vec);
!   Quicksort(u, 0, N)
CONST 60
CONST 0
LDLW 12
GLOBAL tQuicksort.Quicksort
CALL 3
RETURN
END

PROC tQuicksort.Test 61 4 0
! PROCEDURE Test;
!   FOR i := 0 TO N-1 DO a[i] := Random.Roll(10) END;
CONST 0
STLW -4
JUMP 14
LABEL 13
CONST 10
GLOBAL Random.Roll
CALLW 1
LOCAL -244
LDLW -4
CONST 60
BOUND 51
STIW
INCL -4
LABEL 14
LDLW -4
CONST 59
JLEQ 13
!   FOR i := 0 TO N-1 DO Out.Int(a[i], 0) END; Out.Ln;
CONST 0
STLW -4
JUMP 16
LABEL 15
CONST 0
LOCAL -244
LDLW -4
CONST 60
BOUND 52
LDIW
GLOBAL Out.Int
CALL 2
INCL -4
LABEL 16
LDLW -4
CONST 59
JLEQ 15
GLOBAL Out.Ln
CALL 0
!   Sort(a);
LOCAL -244
GLOBAL tQuicksort.Sort
CALL 1
!   FOR i := 0 TO N-1 DO Out.Int(a[i], 0) END; Out.Ln
CONST 0
STLW -4
JUMP 18
LABEL 17
CONST 0
LOCAL -244
LDLW -4
CONST 60
BOUND 54
LDIW
GLOBAL Out.Int
CALL 2
INCL -4
LABEL 18
LDLW -4
CONST 59
JLEQ 17
GLOBAL Out.Ln
CALL 0
RETURN
END

PROC tQuicksort.%main 0 4 0
!   Test
GLOBAL tQuicksort.Test
CALL 0
RETURN
END

! End of file
]]*)

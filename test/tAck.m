MODULE tAck;

IMPORT Out;

(* Definition:

   Ack(0, n) = n+1
   Ack(m+1, 0) = Ack(m, 1)
   Ack(m+1, n+1) = Ack(m, Ack(m+1, n))

Put Ack(m+1, -1) = 1 so that 

   Ack(m+1, n) = Ack(m, Ack(m+1, n-1))

holds for all values of n. *)

PROCEDURE Ack(M, N: INTEGER): INTEGER;
  VAR 
    m: INTEGER;
    arg, val: ARRAY 10 OF INTEGER;
BEGIN
  arg[0] := 0; val[0] := 1;
  FOR m := 1 TO M DO arg[m] := -1; val[m] := 1 END;

  (* Invariant -- for each i,
	(a) val[i] = Ack(i, arg[i]),  
	(b) arg[i] < val[i],  
	(c) arg[i] < val[i+1] *)

  WHILE arg[M] < N DO
    INC(arg[0]); val[0] := arg[0] + 1;
    m := 0;
    WHILE (m <= M) & (arg[m] = val[m+1]) DO
      (* Ack(m+1, arg[m+1]+1) = Ack(m, Ack(m+1, arg[m+1]))
		= Ack(m, val[m+1]) = Ack(m, arg[m]) = val[m] *)
      INC(arg[m+1]); val[m+1] := val[m]; m := m+1
    END
  END;

  RETURN val[M]
END Ack;

VAR memo: ARRAY 10 OF ARRAY 100000 OF INTEGER;

PROCEDURE Ack2(M, N: INTEGER): INTEGER;
  VAR val: INTEGER;
BEGIN
  IF memo[M, N] # 0 THEN RETURN memo[M, N] END;

  IF M = 0 THEN val := N+1
  ELSIF N = 0 THEN val := Ack2(M-1, 1)
  ELSE val := Ack2(M-1, Ack2(M, N-1))
  END;

  memo[M, N] := val;
  RETURN val
END Ack2;

BEGIN
  Out.Int(Ack(4,1), 0); Out.Ln;
  Out.Int(Ack2(4,1), 0); Out.Ln
END tAck.

(* In the inner loop, the main invariant is satisfied except that maybe
arg[m] = val[m+1].  In that case, we can reason as follows

      Ack(m+1, arg[m+1]+1) 
        = Ack(m, Ack(m+1, arg[m+1]))
        = Ack(m, val[m+1]) 
        = Ack(m, arg[m]) 
        = val[m],

so the assignments INC(arg[m+1]); val[m+1] := val[m] maintain (a). 
   
Also arg[m+1] < val[m+1] = arg[m] < val[m] so arg[m+1]+1 < val[m],
and the assignments maintain (b).  They also make (c) true for i = m
whilst perhaps making arg[m+1] = val[m+2]. *)

(*<<
65533
65533
>>*)

(*[[
!! SYMFILE #tAck STAMP #tAck.%main 1
!! END STAMP
!! 
MODULE tAck STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tAck.Ack 22 4 0
! PROCEDURE Ack(M, N: INTEGER): INTEGER;
!   arg[0] := 0; val[0] := 1;
CONST 0
STLW -44
CONST 1
STLW -84
!   FOR m := 1 TO M DO arg[m] := -1; val[m] := 1 END;
LDLW 12
STLW -88
CONST 1
STLW -4
JUMP 2
LABEL 1
CONST -1
LOCAL -44
LDLW -4
CONST 10
BOUND 23
STIW
CONST 1
LOCAL -84
LDLW -4
CONST 10
BOUND 23
STIW
INCL -4
LABEL 2
LDLW -4
LDLW -88
JLEQ 1
JUMP 7
LABEL 3
!     INC(arg[0]); val[0] := arg[0] + 1;
INCL -44
LDLW -44
INC
STLW -84
!     m := 0;
CONST 0
STLW -4
JUMP 6
LABEL 5
!       INC(arg[m+1]); val[m+1] := val[m]; m := m+1
LOCAL -44
LDLW -4
INC
CONST 10
BOUND 36
INDEXW
DUP 0
LOADW
INC
SWAP
STOREW
LOCAL -84
LDLW -4
CONST 10
BOUND 36
LDIW
LOCAL -84
LDLW -4
INC
CONST 10
BOUND 36
STIW
INCL -4
LABEL 6
!     WHILE (m <= M) & (arg[m] = val[m+1]) DO
LDLW -4
LDLW 12
JGT 7
LOCAL -44
LDLW -4
CONST 10
BOUND 33
LDIW
LOCAL -84
LDLW -4
INC
CONST 10
BOUND 33
LDIW
JEQ 5
LABEL 7
!   WHILE arg[M] < N DO
LOCAL -44
LDLW 12
CONST 10
BOUND 30
LDIW
LDLW 16
JLT 3
!   RETURN val[M]
LOCAL -84
LDLW 12
CONST 10
BOUND 40
LDIW
RETURNW
END

PROC tAck.Ack2 1 5 0
! PROCEDURE Ack2(M, N: INTEGER): INTEGER;
!   IF memo[M, N] # 0 THEN RETURN memo[M, N] END;
GLOBAL tAck.memo
LDLW 12
CONST 10
BOUND 48
CONST 100000
TIMES
LDLW 16
CONST 100000
BOUND 48
PLUS
LDIW
JEQZ 9
GLOBAL tAck.memo
LDLW 12
CONST 10
BOUND 48
CONST 100000
TIMES
LDLW 16
CONST 100000
BOUND 48
PLUS
LDIW
RETURNW
LABEL 9
!   IF M = 0 THEN val := N+1
LDLW 12
JNEQZ 11
LDLW 16
INC
STLW -4
JUMP 10
LABEL 11
!   ELSIF N = 0 THEN val := Ack2(M-1, 1)
LDLW 16
JNEQZ 12
CONST 1
LDLW 12
DEC
GLOBAL tAck.Ack2
CALLW 2
STLW -4
JUMP 10
LABEL 12
!   ELSE val := Ack2(M-1, Ack2(M, N-1))
LDLW 16
DEC
LDLW 12
GLOBAL tAck.Ack2
CALLW 2
LDLW 12
DEC
GLOBAL tAck.Ack2
CALLW 2
STLW -4
LABEL 10
!   memo[M, N] := val;
LDLW -4
GLOBAL tAck.memo
LDLW 12
CONST 10
BOUND 55
CONST 100000
TIMES
LDLW 16
CONST 100000
BOUND 55
PLUS
STIW
!   RETURN val
LDLW -4
RETURNW
END

PROC tAck.%main 0 5 0
!   Out.Int(Ack(4,1), 0); Out.Ln;
CONST 0
CONST 1
CONST 4
GLOBAL tAck.Ack
CALLW 2
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
!   Out.Int(Ack2(4,1), 0); Out.Ln
CONST 0
CONST 1
CONST 4
GLOBAL tAck.Ack2
CALLW 2
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
RETURN
END

! Global variables
GLOVAR tAck.memo 4000000

! End of file
]]*)

$Id: tAck.m 1678 2011-03-15 20:27:21Z mike $

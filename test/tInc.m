MODULE tInc;
IMPORT Out;
VAR i: INTEGER;
BEGIN
  i := 10;
  INC(i);
  DEC(i,2);
  INC(i,i);
  Out.Int(i,0);
  Out.Ln
END tInc.

(*<<
18
>>*)

(*[[
!! SYMFILE #tInc STAMP #tInc.%main 1
!! END STAMP
!! 
MODULE tInc STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tInc.%main 0 3 0
!   i := 10;
CONST 10
STGW tInc.i
!   INC(i);
GLOBAL tInc.i
DUP 0
LOADW
INC
SWAP
STOREW
!   DEC(i,2);
GLOBAL tInc.i
DUP 0
LOADW
CONST 2
MINUS
SWAP
STOREW
!   INC(i,i);
GLOBAL tInc.i
DUP 0
LOADW
LDGW tInc.i
PLUS
SWAP
STOREW
!   Out.Int(i,0);
CONST 0
LDGW tInc.i
GLOBAL Out.Int
CALL 2
!   Out.Ln
GLOBAL Out.Ln
CALL 0
RETURN
END

! Global variables
GLOVAR tInc.i 4

! End of file
]]*)

$Id: tInc.m 1678 2011-03-15 20:27:21Z mike $

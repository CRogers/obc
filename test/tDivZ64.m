MODULE tDivZ64;

(*<<
Runtime error: DIV or MOD by zero on line 13 in module tDivZ64
In procedure tDivZ64.%main
   called from MAIN
>>*)

VAR x: LONGINT;

BEGIN
  x := 0;
  x := 1 DIV x
END tDivZ64.

(*[[
!! SYMFILE #tDivZ64 STAMP #tDivZ64.%main 1
!! END STAMP
!! 
MODULE tDivZ64 STAMP 0
ENDHDR

PROC tDivZ64.%main 0 4 0
!   x := 0;
CONST 0
CONVNQ
STGQ tDivZ64.x
!   x := 1 DIV x
CONST 1
CONVNQ
LDGQ tDivZ64.x
QZCHECK 13
QDIV
STGQ tDivZ64.x
RETURN
END

! Global variables
GLOVAR tDivZ64.x 8

! End of file
]]*)

$Id: tDivZ64.m 1678 2011-03-15 20:27:21Z mike $

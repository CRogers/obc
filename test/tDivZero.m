MODULE tDivZero;

(*<<
Runtime error: DIV or MOD by zero on line 13 in module tDivZero
In procedure tDivZero.%main
   called from MAIN
>>*)

VAR x: INTEGER;

BEGIN
  x := 0;
  x := 1 DIV x
END tDivZero.

(*[[
!! SYMFILE #tDivZero STAMP #tDivZero.%main 1
!! END STAMP
!! 
MODULE tDivZero STAMP 0
ENDHDR

PROC tDivZero.%main 0 2 0
!   x := 0;
CONST 0
STGW tDivZero.x
!   x := 1 DIV x
CONST 1
LDGW tDivZero.x
ZCHECK 13
DIV
STGW tDivZero.x
RETURN
END

! Global variables
GLOVAR tDivZero.x 4

! End of file
]]*)

$Id: tDivZero.m 1678 2011-03-15 20:27:21Z mike $

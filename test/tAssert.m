MODULE tAssert;

(*<<
Runtime error: assertion failed (0) on line 12 in module tAssert
In procedure tAssert.Fail
   called from tAssert.%main
   called from MAIN
>>*)

PROCEDURE Fail;
BEGIN
  ASSERT(1 < 0)
END Fail;

BEGIN
  Fail
END tAssert.

(*[[
!! SYMFILE #tAssert STAMP #tAssert.%main 1
!! END STAMP
!! 
MODULE tAssert STAMP 0
ENDHDR

PROC tAssert.Fail 0 1 0
! PROCEDURE Fail;
!   ASSERT(1 < 0)
CONST 0
EASSERT 12
RETURN
END

PROC tAssert.%main 0 1 0
!   Fail
GLOBAL tAssert.Fail
CALL 0
RETURN
END

! End of file
]]*)

$Id: tAssert.m 1678 2011-03-15 20:27:21Z mike $

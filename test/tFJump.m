MODULE tFJump;

(*<<
ok
>>*)

IMPORT Out;

VAR x: REAL;

BEGIN
  x := 1.0;
  IF 0.0 < x THEN
    IF x > 0.5 THEN
      Out.String("ok"); Out.Ln
    END
  END
END tFJump.

(*[[
!! SYMFILE #tFJump STAMP #tFJump.%main 1
!! END STAMP
!! 
MODULE tFJump STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tFJump.%main 0 3 0
!   x := 1.0;
FCONST 1.
STGF tFJump.x
!   IF 0.0 < x THEN
LDGF tFJump.x
FCONST 0.
FJLEQ 3
!     IF x > 0.5 THEN
LDGF tFJump.x
FCONST 0.5
FJLEQ 3
!       Out.String("ok"); Out.Ln
CONST 3
GLOBAL tFJump.%1
GLOBAL Out.String
CALL 2
GLOBAL Out.Ln
CALL 0
LABEL 3
RETURN
END

! Global variables
GLOVAR tFJump.x 4

! String "ok"
DEFINE tFJump.%1
STRING 6F6B00

! End of file
]]*)

$Id: tFJump.m 1678 2011-03-15 20:27:21Z mike $

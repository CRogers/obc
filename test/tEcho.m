MODULE tEcho;

(*<<
dummy arguments
dummy argum
>>*)

IMPORT Args, Out;

PROCEDURE Echo(n: INTEGER);
  VAR i: INTEGER; s: POINTER TO ARRAY OF CHAR;
BEGIN
  NEW(s, n);
  FOR i := 1 TO Args.argc-1 DO
    Args.GetArg(i, s^);
    IF i > 1 THEN Out.Char(' ') END;
    Out.String(s^)
  END;
  Out.Ln
END Echo;

BEGIN
  Echo(20);
  Echo(6)
END tEcho.

(*[[
!! SYMFILE #tEcho STAMP #tEcho.%main 1
!! END STAMP
!! 
MODULE tEcho STAMP 0
IMPORT Args STAMP
IMPORT Out STAMP
ENDHDR

PROC tEcho.Echo 3 6 0x00008001
! PROCEDURE Echo(n: INTEGER);
!   NEW(s, n);
LDLW 12
CONST 1
CONST 1
CONST 0
LOCAL -8
GLOBAL NEWFLEX
CALL 5
!   FOR i := 1 TO Args.argc-1 DO
LDGW Args.argc
DEC
STLW -12
CONST 1
STLW -4
JUMP 2
LABEL 1
!     Args.GetArg(i, s^);
LDLW -8
NCHECK 15
DUP 0
LDNW -4
LDNW 4
SWAP
LDLW -4
GLOBAL Args.GetArg
CALL 3
!     IF i > 1 THEN Out.Char(' ') END;
LDLW -4
CONST 1
JLEQ 4
CONST 32
ALIGNC
GLOBAL Out.Char
CALL 1
LABEL 4
!     Out.String(s^)
LDLW -8
NCHECK 17
DUP 0
LDNW -4
LDNW 4
SWAP
GLOBAL Out.String
CALL 2
!   FOR i := 1 TO Args.argc-1 DO
INCL -4
LABEL 2
LDLW -4
LDLW -12
JLEQ 1
!   Out.Ln
GLOBAL Out.Ln
CALL 0
RETURN
END

PROC tEcho.%main 0 6 0
!   Echo(20);
CONST 20
GLOBAL tEcho.Echo
CALL 1
!   Echo(6)
CONST 6
GLOBAL tEcho.Echo
CALL 1
RETURN
END

! End of file
]]*)

$Id: tEcho.m 1678 2011-03-15 20:27:21Z mike $

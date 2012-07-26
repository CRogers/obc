MODULE tLongShort;
IMPORT Out;

(* Alex Shiryaev: ENTIER(LONGREAL) yields wrong size result *)

TYPE REAL = LONGREAL;

PROCEDURE P* (x: REAL): INTEGER;
  VAR p: INTEGER;
BEGIN
  p := ENTIER(x);
  RETURN p
END P;

BEGIN
  Out.Int(P(3.14), 0); Out.Ln
END tLongShort.

(*<<
3
>>*)

(*[[
!! SYMFILE #tLongShort STAMP #tLongShort.%main 1
!! PROCEDURE #P* 8 #tLongShort.P !0 PROC 2 INTEGER
!!   PARAM #x 12 LONGREAL;;
!! END STAMP
!! 
MODULE tLongShort STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tLongShort.P 1 3 0
! PROCEDURE P* (x: REAL): INTEGER;
!   p := ENTIER(x);
LDLD 12
GLOBAL INTLONG
CALLW 2
STLW -4
!   RETURN p
LDLW -4
RETURNW
END

PROC tLongShort.%main 0 4 0
!   Out.Int(P(3.14), 0); Out.Ln
CONST 0
DCONST 3.14
GLOBAL tLongShort.P
CALLW 2
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
RETURN
END

! End of file
]]*)

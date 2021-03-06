MODULE tDblArg;

IMPORT Out;

PROCEDURE f(b: BOOLEAN; x: LONGREAL); 
BEGIN
  IF b THEN Out.String("*** Failed!") ELSE Out.LongReal(x) END; 
  Out.Ln
END f;

VAR p, q: INTEGER; m: BOOLEAN;

BEGIN
  p := 3; q := 2;
  m := (p < q) & (q DIV 0 > 2);
  f((p < q) & (q DIV 2 > 0), 3.14)
END tDblArg.

(*<<
3.14000000000
>>*)

(*[[
!! SYMFILE #tDblArg STAMP #tDblArg.%main 1
!! END STAMP
!! 
MODULE tDblArg STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tDblArg.f 0 3 0
! PROCEDURE f(b: BOOLEAN; x: LONGREAL); 
!   IF b THEN Out.String("*** Failed!") ELSE Out.LongReal(x) END; 
LDLC 12
JUMPF 3
CONST 12
GLOBAL tDblArg.%1
GLOBAL Out.String
CALL 2
JUMP 2
LABEL 3
LDLD 16
GLOBAL Out.LongReal
CALL 2
LABEL 2
!   Out.Ln
GLOBAL Out.Ln
CALL 0
RETURN
END

PROC tDblArg.%main 0 4 0
!   p := 3; q := 2;
CONST 3
STGW tDblArg.p
CONST 2
STGW tDblArg.q
!   m := (p < q) & (q DIV 0 > 2);
LDGW tDblArg.p
LDGW tDblArg.q
JLT 4
CONST 0
JUMP 5
LABEL 4
LDGW tDblArg.q
CONST 0
ZCHECK 15
DIV
CONST 2
GT
LABEL 5
STGC tDblArg.m
!   f((p < q) & (q DIV 2 > 0), 3.14)
DCONST 3.14
LDGW tDblArg.p
LDGW tDblArg.q
JLT 6
CONST 0
JUMP 7
LABEL 6
LDGW tDblArg.q
CONST 2
DIV
CONST 0
GT
LABEL 7
ALIGNC
GLOBAL tDblArg.f
CALL 3
RETURN
END

! Global variables
GLOVAR tDblArg.p 4
GLOVAR tDblArg.q 4
GLOVAR tDblArg.m 1

! String "*** Failed!"
DEFINE tDblArg.%1
STRING 2A2A2A204661696C65642100

! End of file
]]*)

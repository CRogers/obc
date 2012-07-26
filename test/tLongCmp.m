MODULE tLongCmp;

IMPORT Out;

(* Unsigned comparison must be used for the low-order word of LONGINT *)

(*<<
Good!
>>*)

VAR m: LONGINT;

BEGIN
  m := MAX(INTEGER)+1;
  IF m >= 0 THEN Out.String("Good!") ELSE Out.String("Bad!") END; 
  Out.Ln
END tLongCmp.

(*[[
!! SYMFILE #tLongCmp STAMP #tLongCmp.%main 1
!! END STAMP
!! 
MODULE tLongCmp STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tLongCmp.%main 0 4 0
!   m := MAX(INTEGER)+1;
QCONST 2147483648
STGQ tLongCmp.m
!   IF m >= 0 THEN Out.String("Good!") ELSE Out.String("Bad!") END; 
LDGQ tLongCmp.m
CONST 0
CONVNQ
QJLT 4
CONST 6
GLOBAL tLongCmp.%1
GLOBAL Out.String
CALL 2
JUMP 3
LABEL 4
CONST 5
GLOBAL tLongCmp.%2
GLOBAL Out.String
CALL 2
LABEL 3
!   Out.Ln
GLOBAL Out.Ln
CALL 0
RETURN
END

! Global variables
GLOVAR tLongCmp.m 8

! String "Good!"
DEFINE tLongCmp.%1
STRING 476F6F642100

! String "Bad!"
DEFINE tLongCmp.%2
STRING 4261642100

! End of file
]]*)

(* $Id: tLongCmp.m 1678 2011-03-15 20:27:21Z mike $ *)

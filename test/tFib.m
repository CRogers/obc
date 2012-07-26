MODULE tFib;

(*<<
fib(10) = 55
>>*)

IMPORT Out, FibFun := xPrelude;

BEGIN
  VAR n, f: INTEGER;
  BEGIN
    n := 10;

    f := FibFun.Fib(n);

    Out.String(FibFun.PROC); Out.String("("); Out.Int(n, 0); 
    Out.String(") = "); Out.Int(f, 0); Out.Ln
  END
END tFib.

(*[[
!! SYMFILE #tFib STAMP #tFib.%main 1
!! END STAMP
!! 
MODULE tFib STAMP 0
IMPORT Out STAMP
IMPORT xPrelude STAMP
ENDHDR

PROC tFib.%main 2 3 0
!     n := 10;
CONST 10
STLW -4
!     f := FibFun.Fib(n);
LDLW -4
GLOBAL xPrelude.Fib
CALLW 1
STLW -8
!     Out.String(FibFun.PROC); Out.String("("); Out.Int(n, 0); 
CONST 4
GLOBAL xPrelude.%1
GLOBAL Out.String
CALL 2
CONST 2
GLOBAL tFib.%2
GLOBAL Out.String
CALL 2
CONST 0
LDLW -4
GLOBAL Out.Int
CALL 2
!     Out.String(") = "); Out.Int(f, 0); Out.Ln
CONST 5
GLOBAL tFib.%1
GLOBAL Out.String
CALL 2
CONST 0
LDLW -8
GLOBAL Out.Int
CALL 2
GLOBAL Out.Ln
CALL 0
RETURN
END

! String ") = "
DEFINE tFib.%1
STRING 29203D2000

! String "("
DEFINE tFib.%2
STRING 2800

! End of file
]]*)

$Id: tFib.m 1678 2011-03-15 20:27:21Z mike $

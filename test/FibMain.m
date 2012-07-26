MODULE FibMain;

IMPORT Out, FibFun;

VAR n, f: INTEGER;

BEGIN
  n := 10;

  f := FibFun.Fib(n);

  Out.String(FibFun.name); Out.String("("); Out.Int(n, 0); 
  Out.String(") = "); Out.Int(f, 0); Out.Ln
END FibMain.

$Id: FibMain.m 786 2008-12-23 11:57:29Z mike $

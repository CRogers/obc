MODULE SemDefs;

TYPE fred* = RECORD mint: INTEGER END;

PROCEDURE (VAR x: fred) smile*; END smile;

PROCEDURE (VAR x: fred) frown; END frown;

END SemDefs.

$Id: SemDefs.m 786 2008-12-23 11:57:29Z mike $

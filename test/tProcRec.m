MODULE tProcRec;

IMPORT Out;

TYPE Queue = POINTER TO QueueRec;
  QueueRec = 
   RECORD 
     n: INTEGER;
     Clear: PROCEDURE;
   END;

(* Clear -- set the queue to be empty *)
PROCEDURE Clear; 
BEGIN
  Out.String("Clear"); Out.Ln
END Clear;

VAR noqueue: Queue;

BEGIN
  NEW(noqueue);
  noqueue.Clear := Clear;
  noqueue.Clear
END tProcRec.

(*<<
Clear
>>*)

(*[[
!! SYMFILE #tProcRec STAMP #tProcRec.%main 1
!! END STAMP
!! 
MODULE tProcRec STAMP 0
IMPORT Out STAMP
ENDHDR

PROC tProcRec.Clear 0 3 0
! PROCEDURE Clear; 
!   Out.String("Clear"); Out.Ln
CONST 6
GLOBAL tProcRec.%1
GLOBAL Out.String
CALL 2
GLOBAL Out.Ln
CALL 0
RETURN
END

PROC tProcRec.%main 0 4 0
!   NEW(noqueue);
CONST 8
GLOBAL tProcRec.QueueRec
GLOBAL tProcRec.noqueue
GLOBAL NEW
CALL 3
!   noqueue.Clear := Clear;
GLOBAL tProcRec.Clear
LDGW tProcRec.noqueue
NCHECK 22
STNW 4
!   noqueue.Clear
LDGW tProcRec.noqueue
NCHECK 23
LDNW 4
NCHECK 23
CALL 0
RETURN
END

! Global variables
GLOVAR tProcRec.noqueue 4

! Pointer map
DEFINE tProcRec.%gcmap
WORD GC_BASE
WORD tProcRec.noqueue
WORD 0
WORD GC_END

! String "Clear"
DEFINE tProcRec.%1
STRING 436C65617200

! Descriptor for QueueRec
DEFINE tProcRec.QueueRec
WORD 0
WORD 0
WORD tProcRec.QueueRec.%anc

DEFINE tProcRec.QueueRec.%anc
WORD tProcRec.QueueRec

! End of file
]]*)

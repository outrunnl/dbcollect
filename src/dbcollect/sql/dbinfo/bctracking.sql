PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BLOCK CHANGE TRACKING
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL STATUS      FORMAT A10               HEAD 'Status'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A160              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT status
, bytes/1048576 size_mb
, filename
FROM V$BLOCK_CHANGE_TRACKING
/

CLEAR COMPUTES COLUMNS


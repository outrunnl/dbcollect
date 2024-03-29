PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT FLASHBACK LOGS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL TYPE     FORMAT A10               HEAD 'Type'
COL SIZE_MB  FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME FORMAT A80               HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF FILENAME SIZE_MB ON REPORT

SELECT type
, bytes/1048576 size_mb
, name          filename
FROM V$flashback_database_logfile
/

CLEAR COMPUTES COLUMNS
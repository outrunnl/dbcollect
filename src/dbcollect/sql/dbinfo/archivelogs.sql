PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ARCHIVE LOGS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FILES ON REPORT

COL SIZE_MB    FORMAT 99,999,999,990.99 HEAD 'Size'
COL STATUS     FORMAT A10     HEAD 'Status'
COL FILES      FORMAT 999,999 HEAD 'Files'

SELECT DECODE(STATUS,'A','Active','D','Deleted','X','Expired','U','Unavailable', STATUS) STATUS
, sum(blocks * block_size)/1048576 SIZE_MB
, count(*) FILES
FROM V$ARCHIVED_LOG
WHERE STATUS in ('A','X')
GROUP BY STATUS
ORDER BY STATUS
/

CLEAR COMPUTES COLUMNS

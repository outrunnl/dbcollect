PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE SIZE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF DBFILES SIZE_MB ON REPORT

COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILETYPE    FORMAT A20               HEAD 'Filetype'
COL DBFILES     FORMAT 99990             HEAD 'Files'

SELECT filetype
, dbfiles
, bytes/1048576 SIZE_MB
FROM (
  SELECT 'DATAFILE' filetype, COUNT(*) dbfiles, SUM(bytes) BYTES FROM v$datafile UNION ALL
  SELECT 'TEMPFILE',          COUNT(*),         SUM(bytes) FROM v$tempfile UNION ALL
  SELECT 'REDOLOG',           SUM(members),     SUM(members*bytes) FROM v$log UNION ALL
  SELECT 'STANDBYLOG',        COUNT(member),    SUM(bytes) FROM v$logfile JOIN "V$STANDBY_LOG" USING (GROUP#) UNION ALL
  SELECT 'CONTROLFILE',       COUNT(*),         SUM(block_size * file_size_blks) FROM v$controlfile
)
ORDER BY 1
/

CLEAR COMPUTES COLUMNS

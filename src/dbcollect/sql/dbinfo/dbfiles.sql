PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CORE DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL FILETYPE    FORMAT A20               HEAD 'Filetype'
COL BLOCKSIZE   FORMAT 90.9              HEAD 'BS(K)'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A200              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT TYPE       FILETYPE
, BLOCK_SIZE/1024 BLOCKSIZE
, BYTES/1048576   SIZE_MB
, NAME            FILENAME
FROM (
  SELECT           'DATAFILE' type, bytes, block_size, name   FROM v$datafile
  UNION ALL SELECT 'TEMPFILE',      bytes, block_size, name   FROM v$tempfile
  UNION ALL SELECT 'CONTROLFILE',   block_size*file_size_blks bytes, block_size, name FROM v$controlfile
  UNION ALL SELECT 'REDOLOG',       bytes, blocksize,  member fROM v$log a JOIN v$logfile b USING (group#)
  UNION ALL SELECT 'STANDBYLOG',    bytes, blocksize,  member fROM v$standby_log a JOIN v$logfile b USING (group#)
)
ORDER BY 1, 2
/

CLEAR COMPUTES COLUMNS

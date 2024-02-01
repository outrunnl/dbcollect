PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLESPACE FREE SPACE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME        FORMAT A20               HEAD 'PDB'
COL TABLESPACE_NAME FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB         FORMAT 99,999,999,990.99 HEAD 'Size'
COL FREE_MB         LIKE SIZE_MB             HEAD 'Free'
COL USED_MB         LIKE SIZE_MB             HEAD 'Used'
COL PCT_USED   FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FREE_MB USED_MB ON REPORT

SELECT '-' pdb_name
, tablespace_name
, size_mb
, free_mb
, size_mb - free_mb used_mb
, 100*(size_mb - free_mb)/size_mb pct_used
FROM dba_tablespaces
RIGHT JOIN (SELECT tablespace_name, sum(bytes/1048576) free_mb FROM dba_free_space GROUP BY TABLESPACE_NAME) USING (TABLESPACE_NAME)
RIGHT JOIN (SELECT tablespace_name, sum(bytes/1048576) size_mb FROM dba_data_files GROUP BY TABLESPACE_NAME) USING (TABLESPACE_NAME)
ORDER BY 1, 2, 3
/

CLEAR COMPUTES COLUMNS

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TABLESPACE FREE SPACE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME        FORMAT A20               HEAD 'PDB'
COL TABLESPACE_NAME FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB         FORMAT 99,999,999,990.99 HEAD 'Size'
COL FREE_MB         LIKE SIZE_MB             HEAD 'Free'
COL USED_MB         LIKE SIZE_MB             HEAD 'Used'
COL PCT_USED        FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FREE_MB USED_MB ON REPORT

SELECT COALESCE(name,'-') pdb_name
, tablespace_name
, size_mb
, free_mb
, size_mb - free_mb used_mb
, 100*(size_mb - free_mb)/size_mb pct_used
FROM v$pdbs
RIGHT JOIN (SELECT con_id, tablespace_name, sum(bytes/1048576) free_mb FROM cdb_free_space GROUP BY con_id, TABLESPACE_NAME) USING (con_id)
RIGHT JOIN (SELECT con_id, tablespace_name, sum(bytes/1048576) size_mb FROM cdb_data_files GROUP BY con_id, TABLESPACE_NAME) USING (con_id, tablespace_name)
ORDER BY 1, 2, 3
/

CLEAR COMPUTES COLUMNS
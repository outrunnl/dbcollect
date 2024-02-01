PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TEMPFILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- bad results on 12+

COL PDB_NAME        FORMAT A20               HEAD 'PDB'
COL TABLESPACE_NAME FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB         FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILE_NAME       FORMAT A100              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT '-' pdb_name
, ts.name                   tablespace_name
, bytes/1048576             size_mb
, tf.name                   file_name
FROM v$tempfile tf
JOIN v$tablespace ts USING (ts#)
ORDER BY pdb_name, tablespace_name, FILE#
/

CLEAR COMPUTES COLUMNS
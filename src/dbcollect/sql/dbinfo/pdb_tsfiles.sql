PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TABLESPACE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME        FORMAT A20               HEAD 'PDB'
COL TABLESPACE_NAME FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB         FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILE_NAME       FORMAT A100              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT coalesce(name, '-') pdb_name
, tablespace_name
, bytes/1048576 size_mb
, file_name
FROM cdb_data_files
LEFT JOIN v$pdbs USING (con_id)
ORDER BY 1, 2
/

CLEAR COMPUTES COLUMNS

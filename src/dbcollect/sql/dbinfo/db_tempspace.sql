PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TEMPSPACE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Not 100% reliable!

COL PDB_NAME        FORMAT A20               HEAD 'PDB'
COL TABLESPACE_NAME FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB         FORMAT 99,999,999,990.99 HEAD 'Size'
COL ALLOCATED_MB    LIKE SIZE_MB             HEAD 'Allocated'
COL FREE_MB         LIKE SIZE_MB             HEAD 'Free'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ALLOCATED_MB FREE_MB ON REPORT

SELECT '-' pdb_name
, tablespace_name
, tablespace_size/1048576 size_mb
, allocated_space/1048576 allocated_mb
, free_space/1048576      free_mb
FROM dba_temp_free_space
/

CLEAR COMPUTES COLUMNS
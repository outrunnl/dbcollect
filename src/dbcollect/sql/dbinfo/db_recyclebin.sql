PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT RECYCLEBIN
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME   FORMAT A20               HEAD 'PDB'
COL TS_NAME    FORMAT A25               HEAD 'Tablespace'
COL OBJ_TYPE   FORMAT A20               HEAD 'Type'
COL OBJECTS    FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB    FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB OBJECTS ON REPORT

SELECT '-' pdb_name
, ts_name
, type      obj_type
, COUNT(*)  objects
, SUM(space*block_size/1048576) size_mb
FROM dba_recyclebin
JOIN dba_tablespaces ON ts_name = tablespace_name
GROUP BY ts_name, type
/

CLEAR COMPUTES COLUMNS

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB RECYCLEBIN
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME   FORMAT A20               HEAD 'PDB'
COL TS_NAME    FORMAT A25               HEAD 'Tablespace'
COL OBJ_TYPE   FORMAT A20               HEAD 'Type'
COL OBJECTS    FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB    FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB OBJECTS ON REPORT

SELECT COALESCE(name, '-') pdb_name
, ts_name
, type      obj_type
, COUNT(*)  objects
, SUM(space*cts.block_size/1048576) size_mb
FROM cdb_recyclebin
JOIN cdb_tablespaces cts USING (con_id)
LEFT OUTER JOIN v$pdbs USING (con_id)
WHERE ts_name = tablespace_name
GROUP BY name, ts_name, type
/

CLEAR COMPUTES COLUMNS

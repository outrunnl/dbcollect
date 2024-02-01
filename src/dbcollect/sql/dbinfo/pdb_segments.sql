PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB SEGMENT SIZES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME     FORMAT A20               HEAD 'PDB'
COL SEGMENT_TYPE FORMAT A20               HEAD 'Segment type'
COL OBJECTS      FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB      FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF OBJECTS SIZE_MB ON REPORT

SELECT COALESCE(name, '-') pdb_name
, segment_type
, count(*)                 objects
, sum(bytes/1048576)       size_mb
FROM cdb_segments
LEFT JOIN v$pdbs USING (con_id)
GROUP BY name, segment_type
ORDER BY pdb_name, size_mb
/

CLEAR COMPUTES COLUMNS

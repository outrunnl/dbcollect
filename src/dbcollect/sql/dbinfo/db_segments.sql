PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT SEGMENT SIZES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME     FORMAT A20               HEAD 'PDB'
COL SEGMENT_TYPE FORMAT A20               HEAD 'Segment type'
COL OBJECTS      FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB      FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF OBJECTS SIZE_MB ON REPORT

SELECT '-' pdb_name
, segment_type
, count(*)           objects
, sum(bytes/1048576) size_mb
FROM dba_segments
GROUP BY segment_type
ORDER BY size_mb
/

CLEAR COMPUTES COLUMNS

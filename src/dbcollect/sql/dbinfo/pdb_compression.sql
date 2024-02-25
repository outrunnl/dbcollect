PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TABLE COMPRESSION SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME    FORMAT A20               HEAD 'PDB'
COL COMPRESSION FORMAT A15               HEAD 'Compression'
COL TABLES      FORMAT 999990            HEAD 'Tables'
COL PARTITIONS  LIKE TABLES              HEAD 'Partitions'
COL DATASIZE    FORMAT 99,999,999,990.99 HEAD 'Datasize'
COL ALLOCATED   LIKE DATASIZE            HEAD 'Allocated'
COL EMPTY       LIKE DATASIZE            HEAD 'Empty'
COL RATIO       FORMAT 990.99            HEAD 'Ratio'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF TABLES PARTITIONS DATASIZE ALLOCATED EMPTY ON REPORT

SELECT COALESCE(name, '-') pdb_name
, COALESCE(t.compress_for,'NONE') compression
, SUM(tbl)                     tables
, SUM(part)                    partitions
, SUM(datasize/1048576)        datasize
, SUM(allocated/1048576)       allocated
, SUM(empty/1048576)           empty
, SUM(datasize)/sum(allocated) ratio
FROM (
  SELECT    name, 1 tbl, 0 part, t.compress_for, blocks, ct.block_size * empty_blocks empty, avg_row_len*num_rows datasize, ct.block_size*blocks allocated
  FROM      cdb_tables t
  JOIN      cdb_tablespaces ct USING (con_id, tablespace_name)
  LEFT JOIN v$pdbs USING (con_id)
  UNION ALL
  SELECT    name, 0 tbl, 1 part, p.compress_for, blocks, ct.block_size * empty_blocks empty, avg_row_len*num_rows datasize, ct.block_size*blocks allocated
  FROM      cdb_tab_partitions p
  JOIN      cdb_tablespaces ct USING (con_id, tablespace_name)
  LEFT JOIN v$pdbs USING (con_id)
) t
WHERE blocks > 0
GROUP BY name, t.compress_for
ORDER BY name, t.compress_for NULLS FIRST
/

CLEAR COMPUTES COLUMNS
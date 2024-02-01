PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TABLE COMPRESSION SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME    FORMAT A20               HEAD 'PDB'
COL COMPRESSION FORMAT A15               HEAD 'Compression'
COL TABLES      FORMAT 999990            HEAD 'Tables'
COL PARTITIONS  LIKE TABLES              HEAD 'Partitions'
COL DATASIZE    FORMAT 99,999,999,990.99 HEAD 'Datasize'
COL ALLOCATED   LIKE DATASIZE            HEAD 'Allocated'
COL FREE        LIKE DATASIZE            HEAD 'Free'
COL RATIO       FORMAT 990.99            HEAD 'Ratio'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF TABLES PARTITIONS DATASIZE ALLOCATED FREE ON REPORT

SELECT COALESCE(name, '-') pdb_name
, COALESCE(t.compress_for,'NONE')         compression
, SUM(tbl)                                tables
, SUM(part)                               partitions
, SUM(bytes/1048576)                      datasize
, SUM(ct.block_size*blocks/1048576)       allocated
, SUM(ct.block_size*empty_blocks/1048576) free
, SUM(bytes)/sum(ct.block_size*blocks)    ratio
FROM (
  SELECT con_id, tablespace_name, num_rows, 1 tbl, 0 part, compress_for,
         blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space
  FROM cdb_tables
  UNION ALL
  SELECT con_id, tablespace_name, num_rows, 0 tbl, 1 part, compress_for,
         blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space
  FROM cdb_tab_partitions
) t
JOIN cdb_tablespaces ct USING (con_id, tablespace_name)
LEFT JOIN v$pdbs USING (con_id)
WHERE blocks > 0
GROUP BY name, t.compress_for
ORDER BY name, t.compress_for NULLS FIRST
/

CLEAR COMPUTES COLUMNS
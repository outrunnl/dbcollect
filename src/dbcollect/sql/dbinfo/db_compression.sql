PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLE COMPRESSION SUMMARY
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
COMPUTE SUM LABEL "Total" OF TABLES PARTITIONS DATASIZE ALLOCATED FREE ON REPORT

SELECT '-' pdb_name
, COALESCE(t.compress_for,'NONE') compression
, SUM(tbl)                     tables
, SUM(part)                    partitions
, SUM(datasize/1048576)        datasize
, SUM(allocated/1048576)       allocated
, SUM(empty/1048576)           empty
, SUM(datasize)/sum(allocated) ratio
FROM (
  SELECT tablespace_name, 1 tbl, 0 part, t.compress_for, blocks, block_size*empty_blocks empty, avg_row_len*num_rows datasize, avg_space, block_size*blocks allocated
  FROM dba_tables t
  JOIN dba_tablespaces USING (tablespace_name)
  UNION ALL
  SELECT tablespace_name, 0 tbl, 1 part, p.compress_for, blocks, block_size*empty_blocks empty, avg_row_len*num_rows datasize, avg_space, block_size*blocks allocated
  FROM dba_tab_partitions p
  JOIN dba_tablespaces USING (tablespace_name)
) t
WHERE blocks > 0
GROUP BY t.compress_for
ORDER BY t.compress_for NULLS FIRST
/

CLEAR COMPUTES COLUMNS

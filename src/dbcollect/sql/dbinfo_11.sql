-- -----------------------------------------------------------------------------
-- Title       : dbinfo_11.sql
-- Description : collect database information
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- -----------------------------------------------------------------------------
-- Runs sections that only work on 11g and higher. Not yet complete.
-- Revision history:
-- 1.3.2 - Moved sections from dbinfo.sql, added block change tracking

SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DNFS SERVERS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL SVRNAME FORMAT A40  HEAD 'NFS Server'
COL DIRNAME FORMAT A120 HEAD 'Directory'
SELECT svrname, dirname
FROM v$dnfs_servers
/

CLEAR COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLE COMPRESSION SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Works only on 11g+

COL MIB         FORMAT 999999990.99
COL compression FORMAT A15        head 'Compression'
COL tables      FORMAT 999990     head 'Tables'
COL partitions  LIKE tables       head 'Part'
COL datasize    LIKE MIB          head 'Datasize'
COL allocated   LIKE MIB          head 'Allocated'
COL free        LIKE MIB          head 'Free'
COL ratio       FORMAT 990.99     head 'Ratio'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF TABLES PARTITIONS DATASIZE ALLOCATED FREE ON REPORT

SELECT coalesce(t.compress_for,'NONE') compression
, SUM(tbl)                             tables
, SUM(bytes)/1048576                   datasize
, SUM(block_size*blocks)/1048576       allocated
, SUM(block_size*empty_blocks)/1048576 free
, SUM(bytes)/sum(block_size*blocks)    ratio
FROM (
  SELECT tablespace_name, num_rows, 1 tbl, 0 part, compress_for
  , blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space FROM dba_tables
  UNION ALL
  SELECT tablespace_name, num_rows, 0 tbl, 1 part, compress_for
  , blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space FROM dba_tab_partitions
) t
JOIN dba_tablespaces USING (tablespace_name)
WHERE blocks > 0
GROUP BY t.compress_for
ORDER BY t.compress_for NULLS FIRST
/

CLEAR COMPUTES COLUMNS

PROMPT

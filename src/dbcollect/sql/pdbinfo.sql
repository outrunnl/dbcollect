-- ----------------------------------------------------------------------------
-- File Name    : pdbinfo.sql
-- Author       : Bart Sjerps
-- Description  : Report Pluggable Database (PDB) info
-- ----------------------------------------------------------------------------
-- Requires: Oracle database >= 12.1
-- This script collects pluggable database and container DB info
-- ----------------------------------------------------------------------------
-- Revision history:
-- 1.3.5 - Adding PDB segment sizes, compress summary, ts objects

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDBINFO version 1.3.5
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CONTAINER INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


COL METRIC      FORMAT A20        HEAD 'Metric'
COL VALUE       FORMAT A80        HEAD 'Value'

SELECT 'report date' metric,           to_char(sysdate) value FROM dual
UNION ALL SELECT 'CDB',                CDB                    FROM V$DATABASE
UNION ALL SELECT 'hostname',           host_name              FROM V$INSTANCE
UNION ALL SELECT 'dbname',             name                   FROM V$DATABASE
UNION ALL SELECT 'dbid',               to_char(dbid)          FROM V$DATABASE
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB DATABASES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME  FORMAT A20        HEAD 'PDB'
COL PDB_ID    FORMAT 9999       HEAD 'PDBID'
COL DBID      FORMAT 9999999999 HEAD 'DBID'
COL GUID      FORMAT A32        HEAD 'GUID'
COL OPEN_MODE FORMAT A10        HEAD 'Mode'

BREAK ON REPORT
COMPUTE NUM LABEL "Total" OF DBID ON REPORT

SELECT name PDB_NAME
, con_id PDB_ID
, dbid
, guid
, open_mode
FROM v$pdbs
ORDER BY name
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME  FORMAT A20               HEAD 'PDB'
COL TS_NAME   FORMAT A25               HEAD 'Tablespace'
COL SIZE_MB   FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME  FORMAT A180              HEAD 'Filename'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT P.NAME   PDB_NAME
, T.name        TS_NAME
, bytes/1048576 SIZE_MB
, filename
FROM (
    SELECT CON_ID
    , 'DATAFILE'        FILETYPE
    , ts#
    , bytes
    , D.block_size/1024 BLOCKSIZE
    , D.name            FILENAME
    FROM v$datafile D
    UNION ALL
    SELECT CON_ID
    , 'TEMPFILE'
    , ts#
    , bytes
    , D.block_size/1024
    , D.name
    FROM v$tempfile D) F
LEFT OUTER JOIN v$pdbs P USING (con_id)
LEFT OUTER JOIN v$tablespace T USING (con_id, ts#)
ORDER BY pdb_name NULLS FIRST, ts_name
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB TABLESPACES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME  FORMAT A20               HEAD 'PDB'
COL TS_NAME   FORMAT A25               HEAD 'Tablespace'
COL DBFILES   FORMAT 9990              HEAD 'Files'
COL TS_TYPE   FORMAT A8                HEAD 'Type'
COL COMPR     FORMAT A6                HEAD 'Compr'
COL ENCR      FORMAT A6                HEAD 'Encr'
COL OBJECTS   FORMAT 999,990           HEAD 'Objects'
COL USED_MB   FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB   LIKE USED_MB             HEAD 'Free'
COL ALLOCATED LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED  FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF DBFILES ALLOCATED FREE_MB USED_MB ON REPORT

SELECT TS.PDB_NAME
, TS.TS_NAME
, COUNT(*) DBFILES
, TS_TYPE
, COMPR
, ENCR
, (SELECT count(*) FROM cdb_segments WHERE cdb_segments.tablespace_name = ts.ts_name) objects
, ALLOCATED - FREE_MB USED_MB
, FREE_MB
, ALLOCATED
, 100 * (ALLOCATED - FREE_MB) / nullif(ALLOCATED,0) PCT_USED
FROM (
    SELECT P.name                 PDB_NAME
    , tablespace_name             TS_NAME
    , DECODE(contents,'PERMANENT',DECODE(extent_management,'LOCAL',DECODE(allocation_type,'UNIFORM','LM-UNI','LM-SYS'),'DM'),'TEMPORARY','TEMP',contents) TS_TYPE
    , compress_for                COMPR
    , DECODE(ENCRYPTED,'NO',NULL) ENCR
    , SUM(DF.BYTES/1048576)       ALLOCATED
    FROM cdb_tablespaces CT
    LEFT OUTER JOIN v$pdbs P USING(con_id)
    JOIN cdb_data_files DF USING(con_id, TABLESPACE_NAME)
    GROUP BY p.name, tablespace_name, COMPRESS_FOR, ENCRYPTED,contents, allocation_type, extent_management
) TS,
(
    SELECT COALESCE(P.name,'ROOT') PDB_NAME
    , FS.tablespace_name           TS_NAME
    , SUM(fs.bytes/1048576)        FREE_MB
    FROM cdb_free_space FS
    LEFT OUTER JOIN v$pdbs P USING (con_id)
    GROUP BY p.name, fs.tablespace_name
) FS
WHERE TS.PDB_NAME = FS.PDB_NAME
AND   TS.TS_NAME = FS.TS_NAME
GROUP BY TS.PDB_NAME, TS.TS_NAME, TS_TYPE, COMPR, ENCR, FS.FREE_MB, ALLOCATED
ORDER BY PDB_NAME, TS_NAME, TS_TYPE
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB SEGMENT SIZES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME    FORMAT A20               HEAD 'PDB'
COL SEGTYPE     FORMAT A20               HEAD 'Segtype'
COL OBJECTS     FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF OBJECTS SIZE_MB ON REPORT

SELECT name          PDB_NAME
, segment_type       SEGTYPE
, count(*)           OBJECTS
, sum(bytes)/1048576 SIZE_MB
FROM cdb_segments
JOIN v$pdbs USING (con_id)
GROUP BY name, segment_type
ORDER BY name, size_mb
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLE COMPRESSION SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME    FORMAT A20               HEAD 'PDB'
COL COMPRESSION FORMAT A15               HEAD 'Compression'
COL TABLES      FORMAT 999990            HEAD 'Tables'
COL DATASIZE    FORMAT 99,999,999,990.99 HEAD 'Datasize'
COL ALLOCATED   LIKE DATASIZE            HEAD 'Allocated'
COL FREE        LIKE DATASIZE            HEAD 'Free'
COL RATIO       FORMAT 990.99            HEAD 'Ratio'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF TABLES PARTITIONS DATASIZE ALLOCATED FREE ON REPORT

SELECT name                               pdb_name
, coalesce(t.compress_for,'NONE')         compression
, SUM(tbl)                                tables
, SUM(bytes)/1048576                      datasize
, SUM(ct.block_size*blocks)/1048576       allocated
, SUM(ct.block_size*empty_blocks)/1048576 free
, SUM(bytes)/sum(ct.block_size*blocks)    ratio
FROM (
  SELECT con_id, tablespace_name, num_rows, 1 tbl, 0 part, compress_for
  , blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space FROM cdb_tables
  UNION ALL
  SELECT con_id, tablespace_name, num_rows, 0 tbl, 1 part, compress_for
  , blocks, empty_blocks, avg_row_len*num_rows bytes, avg_space FROM cdb_tab_partitions
) t
JOIN cdb_tablespaces ct USING (con_id, tablespace_name)
JOIN v$pdbs USING (con_id)
WHERE blocks > 0
GROUP BY name, t.compress_for
ORDER BY name, t.compress_for NULLS FIRST
/

CLEAR COMPUTES COLUMNS

-- ----------------------------------------------------------------------------
-- File Name    : pdbinfo.sql
-- Author       : Bart Sjerps
-- Description  : Report Pluggable Database (PDB) info
-- ----------------------------------------------------------------------------
-- Requires: Oracle database >= 12.1
-- This script collects pluggable database and container DB info
-- ----------------------------------------------------------------------------

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDBINFO version 1.2.0
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

SELECT P.NAME PDB_NAME
-- , FILETYPE
-- , F.con_id
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
LEFT OUTER JOIN v$pdbs P ON P.con_id = F.con_id
LEFT OUTER JOIN v$tablespace T ON T.con_id = F.con_id AND F.ts# = T.ts#
ORDER BY F.con_id, ts_name
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
, ALLOCATED - FREE_MB USED_MB
, ALLOCATED
, FREE_MB
FROM (
    SELECT P.name                 PDB_NAME
    , CT.tablespace_name          TS_NAME
    , DECODE(contents,'PERMANENT',DECODE(extent_management,'LOCAL',DECODE(allocation_type,'UNIFORM','LM-UNI','LM-SYS'),'DM'),'TEMPORARY','TEMP',contents) TS_TYPE
    , compress_for COMPR
    , DECODE(ENCRYPTED,'NO',NULL) ENCR
    , SUM(DF.BYTES/1048576)       ALLOCATED
    FROM cdb_tablespaces CT
    LEFT OUTER JOIN v$pdbs P ON CT.con_id = p.con_id
    JOIN cdb_data_files DF ON CT.TABLESPACE_NAME = DF.TABLESPACE_NAME AND CT.CON_ID = DF.CON_ID
    GROUP BY p.name, CT.tablespace_name, COMPRESS_FOR, ENCRYPTED,contents, allocation_type, extent_management
) TS,
(
    SELECT COALESCE(P.name,'ROOT') PDB_NAME
    , FS.tablespace_name           TS_NAME
    , SUM(fs.bytes/1048576)        FREE_MB
    FROM cdb_free_space FS
    LEFT OUTER JOIN v$pdbs P ON FS.con_id = p.con_id
    GROUP BY p.name, FS.con_id, fs.tablespace_name
) FS
WHERE TS.PDB_NAME = FS.PDB_NAME
AND   TS.TS_NAME = FS.TS_NAME
GROUP BY TS.PDB_NAME, TS.TS_NAME, TS_TYPE, COMPR, ENCR, FS.FREE_MB, ALLOCATED
ORDER BY 1,2
/

CLEAR COMPUTES COLUMNS

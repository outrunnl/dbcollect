-- -----------------------------------------------------------------------------
-- Title       : dbinfo.sql
-- Description : collect database information
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- -----------------------------------------------------------------------------
-- Requires: Oracle database >= 11.2
--
-- This script collects database info about the current connected database
--
-- Each section is separated by a header, columns are separated by '|' to
-- have both reasonable readability and parseability.
-- Sizes are in Mibibytes (MiB) unless otherwise specified.
--
-- Created by Bart Sjerps with code snippets from
-- various people, including Graham Thornton, Asad Samdani and others.
--
-- This script uses only SELECT and SQL*Plus formatting/reporting statements,
-- will not modify (update) any tables and therefore is safe to use on
-- production systems.
--
-- Revision history:
-- 1.0   - first version
-- 1.0.1 - Added TAB OFF to avoid messed up formatting (Bart Sjerps)
-- 1.1.1 - Increased column width/sizes b/c customers had huge databases
--         Max size of any MIB value now 99 petabyte. Should be enough.
--         Feature usage now shows 1 column per feature + inuse + version
-- 1.1.2 - Added platform from v$database
-- 1.2.0 - No longer breaks when MOUNTED/STARTED, split instance/database, fix
--         cpu count for RAC, removed spool parameters, break headings in
--         sections, added archivelogs, asmdisks, dnfs + awr sections,
--         many small fixes, wider page
-- 1.3.0 - Added ASM files summary section, fix backup file report
-- 1.3.1 - Added Compression summary
-- 1.3.2 - Clean up some formatting, moved 11g sections to new file
-- 1.3.3 - Added daily archivelog rate, changed some reports, separate flashback
--         log summary
-- 1.3.4 - Adjusted SIZE_MB for archivelog summary
-- -----------------------------------------------------------------------------

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

-- set emb on

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DBINFO version 1.3.4
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INSTANCE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL METRIC FORMAT A20  HEAD 'Metric'
COL VALUE  FORMAT A160 HEAD 'Value'

SELECT 'report date' metric,       to_char(sysdate) value   FROM dual
UNION ALL SELECT 'hostname',       host_name                FROM v$instance
UNION ALL SELECT 'instance',       instance_name            FROM v$instance
UNION ALL SELECT 'version',        version                  FROM v$instance
UNION ALL SELECT 'inst_number',    to_char(instance_number) FROM v$instance
UNION ALL SELECT 'startup',        to_char(startup_time)    FROM v$instance
UNION ALL SELECT 'rac',            parallel                 FROM v$instance
UNION ALL SELECT 'inst_role',      instance_role            FROM v$instance
UNION ALL SELECT 'status',         status                   FROM v$instance
UNION ALL SELECT 'db_status',      database_status          FROM v$instance
UNION ALL SELECT 'logins',         logins                   FROM v$instance
UNION ALL SELECT 'blocked',        blocked                  FROM v$instance -- 11+ only?
UNION ALL SELECT 'uptime (days)',  to_char(round(sysdate - startup_time,2)) FROM v$instance
UNION ALL SELECT lower(replace(stat_name,'NUM_','')), to_char(value)
          FROM   v$osstat
          WHERE  stat_name IN ('NUM_CPUS','NUM_CPU_CORES','NUM_CPU_SOCKETS')
UNION ALL SELECT 'memory', to_char(round(value/1048576))
          FROM   v$osstat
          WHERE  stat_name = 'PHYSICAL_MEMORY_BYTES'
UNION ALL SELECT 'product', substr(banner, 1, instr(banner,'Release')-2)
          FROM   v$version
          WHERE  banner LIKE 'Oracle Database%'
/

CLEAR COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL METRIC FORMAT A20        HEAD 'Metric'
COL VALUE  FORMAT A160       HEAD 'Value'

SELECT 'dbname' metric,              name value                   FROM v$database
UNION ALL SELECT 'platform',         platform_name                FROM v$database
UNION ALL SELECT 'dbid',             to_char(dbid)                FROM v$database
UNION ALL SELECT 'unique_name',      db_unique_name               FROM v$database
UNION ALL SELECT 'open_mode',        open_mode                    FROM v$database
UNION ALL SELECT 'log_mode',         log_mode                     FROM v$database
UNION ALL SELECT 'force_logging',    force_logging                FROM v$database
UNION ALL SELECT 'prot_mode',        protection_mode              FROM v$database
UNION ALL SELECT 'prot_level',       protection_level             FROM v$database
UNION ALL SELECT 'db_role',          database_role                FROM v$database
UNION ALL SELECT 'flashback',        flashback_on                 FROM v$database
UNION ALL SELECT 'created',          to_char(created)             FROM v$database
UNION ALL SELECT 'ctrlfile_type',    controlfile_type             FROM v$database
UNION ALL SELECT 'ctrlfile_created', to_char(controlfile_created) FROM v$database
UNION ALL SELECT 'switchover',       switchover_status            FROM v$database
UNION ALL SELECT 'dgbroker',         dataguard_broker             FROM v$database
UNION ALL SELECT 'arch_compress',    archivelog_compression       FROM v$database
-- UNION ALL SELECT 'primary_u_name',   primary_db_unique_name       FROM v$database
/

CLEAR COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE SIZE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF DBFILES SIZE_MB ON REPORT

COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILETYPE    FORMAT A20               HEAD 'Filetype'
COL DBFILES     FORMAT 99990             HEAD 'Files'

SELECT FTYPE FILETYPE
, DBFILES
, BYTES/1048576 SIZE_MB
FROM (
  SELECT 'datafiles' ftype,        count(*) dbfiles, sum(bytes) BYTES FROM v$datafile
  UNION ALL SELECT 'tempfiles',    count(*),         sum(bytes) FROM v$tempfile
  UNION ALL SELECT 'redologs',     sum(members),     sum(bytes) FROM v$log
  UNION ALL SELECT 'controlfiles', count(*),         sum(block_size * file_size_blks) FROM v$controlfile
)
ORDER BY 1
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CORE DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

COL FILETYPE    FORMAT A20               HEAD 'Filetype'
COL BLOCKSIZE   FORMAT 90.9              HEAD 'BS(K)'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A200              HEAD 'Filename'

SELECT TYPE       FILETYPE
, BLOCK_SIZE/1024 BLOCKSIZE
, BYTES/1048576   SIZE_MB
, NAME            FILENAME
FROM (
  SELECT           'DATAFILE' type, bytes, block_size, name   FROM v$datafile
  UNION ALL SELECT 'TEMPFILE',      bytes, block_size, name   FROM v$tempfile
  UNION ALL SELECT 'CONTROLFILE',   block_size*file_size_blks bytes, block_size, name FROM v$controlfile
  UNION ALL SELECT 'REDOLOG',       bytes, blocksize,  member fROM v$log a JOIN v$logfile b ON a.Group#=b.Group#
)
ORDER BY 1, 2
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ARCHIVE LOGS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FILES ON REPORT

COL SIZE_MB    FORMAT 99,999,999,990.99 HEAD 'Size'
COL STATUS     FORMAT A10     HEAD 'Status'
COL FILES      FORMAT 999,999 HEAD 'Files'

SELECT DECODE(STATUS,'A','Active','D','Deleted','X','Expired','U','Unavailable', STATUS) STATUS
, sum(blocks * block_size)/1048576 SIZE_MB
, count(*) FILES
FROM V$ARCHIVED_LOG
WHERE STATUS in ('A','X')
GROUP BY STATUS
ORDER BY STATUS
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DAILY ARCHIVELOG SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF FILES SIZE_MB ON REPORT

COL DS        FORMAT A12               HEADING 'Date'
COL WEEKDAY   FORMAT A4                HEADING 'Day'
COL FILES     FORMAT 9990              HEADING 'Logs'
COL SIZE_MB   FORMAT 99,999,999,990.99 HEAD    'Size'
COL AVG7      LIKE SIZE_MB             HEADING 'Week avg'

SELECT to_char(datestamp,'YYYY-MM-DD') ds
, to_char(datestamp,'Dy') weekday
, files
, size_mb
, AVG(size_mb) OVER (ORDER BY rn DESC rows BETWEEN 6 preceding AND current row) avg7
FROM (SELECT datestamp
  , COUNT(*) files
  , SUM(bytes/1048576) SIZE_MB
  , ROW_NUMBER() OVER (ORDER BY datestamp DESC) rn
  FROM (SELECT TRUNC(completion_time) datestamp, (blocks * block_size) BYTES FROM v$archived_log)
  GROUP BY datestamp
)
WHERE rn BETWEEN 2 AND 100
ORDER BY datestamp
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BACKUPS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FILES ON REPORT

COL FILE_TYPE    FORMAT A15    HEAD 'File type'
COL OBSOLETE     FORMAT A8     HEAD 'Obsolete'
COL BACKUPTYPE   FORMAT A12    HEAD 'Backup type'
COL BS_INCR_TYPE FORMAT A12    HEAD 'Level'
COL COMPRESSED   FORMAT A10    HEAD 'Compressed'
COL STATUS       FORMAT A12    HEAD 'Status'
COL SIZE_MB      FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILES        FORMAT 999990 HEAD 'Files'

SELECT file_type
, obsolete
, backup_type  BACKUPTYPE
, bs_incr_type LVL
, COMPRESSED
, STATUS
, SUM(BYTES)/1048576 SIZE_MB
, COUNT(*)           FILES
FROM V$BACKUP_FILES
WHERE file_type NOT IN ('DATAFILE')
GROUP BY FILE_TYPE, BACKUP_TYPE, BS_INCR_TYPE, COMPRESSED, OBSOLETE, STATUS
ORDER BY OBSOLETE DESC, FILE_TYPE
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BLOCK CHANGE TRACKING
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL STATUS      FORMAT A10               HEAD 'Status'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A160              HEAD 'Filename'

SELECT status
, bytes/1048576 SIZE_MB
, filename
FROM V$BLOCK_CHANGE_TRACKING
/

CLEAR COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT FLASHBACK LOGS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL TYPE     FORMAT A10
COL SIZE_MB  FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME FORMAT A80

SELECT type
, bytes/1048576 SIZE_MB
, name          FILENAME
FROM V$FLASHBACK_DATABASE_LOGFILE
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLESPACES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL TS_NAME    FORMAT A25               HEAD 'Tablespace'
COL FILES      FORMAT 999990            HEAD 'Files'
COL TS_TYPE    FORMAT A8                HEAD 'Type'
COL COMPR      FORMAT A6                HEAD 'Compr'
COL ENCR       FORMAT A6                HEAD 'Encr'
COL OBJECTS    FORMAT 999,990           HEAD 'Objects'
COL USED_MB    FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB    LIKE USED_MB             HEAD 'Free'
COL ALLOCATED  LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED   FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF FILES ALLOCATED FREE_MB USED_MB OBJECTS ON REPORT

WITH DF AS (SELECT tablespace_name
  , (SELECT count(*) FROM dba_segments WHERE dba_segments.tablespace_name = DF.tablespace_name) objects
  , count(*) files
  , sum(bytes)/1024/1024 allocated
  FROM dba_data_files DF
  WHERE status = 'AVAILABLE'
  GROUP BY tablespace_name
), FS AS (SELECT fs.tablespace_name
  , sum(fs.bytes)/1024/1024 free_mb
  FROM dba_free_space fs
  GROUP BY tablespace_name
), TS AS ( SELECT tablespace_name
  , DECODE(contents,'PERMANENT',DECODE(extent_management,'LOCAL',DECODE(allocation_type,'UNIFORM','LM-UNI','LM-SYS'),'DM'),'TEMPORARY','TEMP',contents) ts_type
  , SUBSTR(replace(replace(compress_for,'QUERY', 'Q'),'ARCHIVE','A'),1,6) COMPR
  , ENCRYPTED
  FROM dba_tablespaces
)
SELECT DF.tablespace_name ts_name
, files
, ts_type
, compr
, encrypted encr
, objects
, allocated - free_mb used_mb
, free_mb
, allocated
, 100 * (allocated - free_mb) / nullif(allocated,0) PCT_USED
FROM   DF, FS, TS
WHERE  fs.tablespace_name = DF.tablespace_name
AND    fs.tablespace_name = TS.tablespace_name
GROUP BY DF.tablespace_name,ts_type,compr,encrypted,free_mb,allocated,files,objects
UNION ALL
SELECT TF.tablespace_name
, count(*)             files
, 'TEMP'               ts_type
, NULL                 COMPR
, 'NO'                 ENCR
, 0                    objects
, (sum(bytes)-bytes_free)/1024/1024 used_mb
, bytes_free/1024/1024 free_mb
, sum(bytes/1024/1024) allocated
, 100*(sum(bytes)-bytes_free)/sum(bytes) pct_used
FROM dba_temp_files TF
LEFT JOIN v$temp_space_header H ON TF.tablespace_name = H.tablespace_name
GROUP BY tf.tablespace_name, bytes,bytes_free
ORDER BY 1
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT SEGMENT SIZES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL SEGTYPE     FORMAT A20               HEAD 'Segtype'
COL OBJECTS     FORMAT 999,990           HEAD 'Objects'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'

BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF OBJECTS SIZE_MB ON REPORT

SELECT segment_type  SEGTYPE
, count(*)           OBJECTS
, sum(bytes)/1048576 SIZE_MB
FROM dba_segments
GROUP BY segment_type
ORDER BY size_mb
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISK GROUPS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DG_NAME   FORMAT A25               HEAD 'Diskgroup'
COL AU_SIZE   FORMAT 99                HEAD 'AU'
COL MIRRORS   FORMAT 9                 HEAD 'Mir'
COL USED_MB   FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB   LIKE USED_MB             HEAD 'Free'
COL ALLOCATED LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED  FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT name dg_name
, allocation_unit_size/1024/1024 au_size
-- , decode(state,'MOUNTED','Y','CONNECTED','Y','DISMOUNTED','N','E') state
, DECODE(type, 'EXTERN',1,'NORMAL',2,'HIGH',3,0) MIRRORS
, (total_mb - free_mb) USED_MB
, free_mb              FREE_MB
, total_mb             ALLOCATED
, ROUND((1- (free_mb / NULLIF(total_mb,0)))*100, 2) PCT_USED
FROM v$asm_diskgroup
ORDER BY name
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISKS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DISKNAME   FORMAT A30               HEAD 'Disk name'
COL DG_NAME    FORMAT A30               HEAD 'Diskgroup'
COL PATH       FORMAT A120              HEAD 'Path'
COL USED_MB    FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB    LIKE USED_MB             HEAD 'Free'
COL ALLOCATED  LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED   FORMAT 990.99            HEAD 'Used %'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT  disk.name                  DISKNAME
, COALESCE(dg.name, header_status) DG_NAME
, (disk.total_mb - disk.free_mb)   USED_MB
, disk.free_mb                     FREE_MB
, disk.os_mb                       ALLOCATED
, 100*(disk.total_mb - disk.free_mb)/nullif(disk.total_mb,0) PCT_USED
-- , disk.state
, path
FROM gv$asm_disk disk
LEFT OUTER JOIN v$asm_diskgroup dg ON disk.group_number = dg.group_number AND dg.group_number <> 0
JOIN v$instance ON inst_id=instance_number
ORDER BY disk.name,path
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB SPACE_MB FILES ON REPORT

COL FILETYPE  FORMAT A20               HEAD 'Filetype'
COL DG_NAME   FORMAT A25               HEAD 'Diskgroup'
COL SIZE_MB   FORMAT 99,999,999,990.99 HEAD 'Size'
COL SPACE_MB  LIKE SIZE_MB             HEAD 'Allocated'
COL FILES     FORMAT 999990            HEAD 'Files'

SELECT f.type filetype
, name dg_name
, sum(f.bytes)/1048576 SIZE_MB
, sum(f.space)/1048576 SPACE_MB
, count(*) files
FROM v$asm_file f
JOIN v$asm_diskgroup d USING (group_number)
GROUP BY f.type, name
ORDER BY 1, 2
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR RETENTION
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL METRIC  FORMAT A20    HEAD 'Metric'
COL MINUTES FORMAT 999999 HEAD 'Minutes'

SELECT 'Interval' Metric
, extract(day from snap_interval)*24*60 +
  extract(hour from snap_interval)*60 +
  extract(minute from snap_interval) MINUTES
FROM dba_hist_wr_control UNION ALL
SELECT 'Retention'
, extract(day from retention)*24*60 +
  extract(hour from retention)*60 +
  extract(minute from retention) MINUTES
FROM dba_hist_wr_control
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR SNAPSHOTS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID       FORMAT 9999999999
COL INSTNUM    FORMAT 99         HEAD 'Instnum'
COL SNAPSHOTS  FORMAT 9999       HEAD 'Snapshots'
COL SNAPFIRST  FORMAT 9999999    HEAD 'First ID'
COL SNAPSTART  FORMAT A20        HEAD 'Start'
COL TZ         FORMAT A20        HEAD 'Timezone'
COL SNAPLEVEL  FORMAT 99         HEAD 'Level'
COL SNAPFLAG   FORMAT 99         HEAD 'Flag'
COL SNAPEND    LIKE SNAPSTART    HEAD 'End'
COL SNAPLAST   LIKE SNAPFIRST    HEAD 'Last ID'

SELECT DBID
, INSTANCE_NUMBER          INSTNUM
, SNAP_LEVEL               SNAPLEVEL
, SNAP_FLAG                SNAPFLAG
, COUNT(*)                 SNAPSHOTS
, MIN(SNAP_ID)             SNAPFIRST
, MAX(SNAP_ID)             SNAPLAST
, MIN(BEGIN_INTERVAL_TIME) SNAPSTART
, MAX(BEGIN_INTERVAL_TIME) SNAPEND
, SNAP_TIMEZONE            TZ
FROM dba_hist_snapshot
GROUP BY DBID, INSTANCE_NUMBER, SNAP_TIMEZONE, SNAP_LEVEL, SNAP_FLAG
ORDER BY DBID, SNAP_FLAG, INSTANCE_NUMBER
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INIT PARAMETERS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Non-null/non-default init parameters

COL PARAMETER   FORMAT A40  HEAD 'Parameter'
COL MODIFIED    FORMAT A10  HEAD 'Modified'
COL VALUE       FORMAT A160 HEAD 'Value'

SELECT name parameter
, DECODE(ismodified,'FALSE','','SYSTEM_MOD','SYSTEM','MODIFIED','SESSION',ismodified) MODIFIED
, value
FROM v$parameter
WHERE value IS NOT NULL
AND (isdefault = 'FALSE' OR ISMODIFIED != 'FALSE')
ORDER BY name
/

CLEAR COMPUTES COLUMNS

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE FEATURE USAGE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Thanks to Oracle-base, see https://oracle-base.com/articles/misc/tracking-database-feature-usage

COL FEATURE FORMAT A55   HEAD 'Feature'
COL USAGES  FORMAT 9,999 HEAD 'Usage'
COL INUSE   FORMAT A10   HEAD 'In Use'
COL VERSION FORMAT A14   HEAD 'Version'

SELECT u1.name feature, u1.detected_usages usages, u1.currently_used inuse, u1.version version
-- , u1.first_usage_date, u1.last_usage_date, u1.description
FROM   dba_feature_usage_statistics u1
WHERE  u1.version = (SELECT MAX(u2.version)
                     FROM   dba_feature_usage_statistics u2
                     WHERE  u2.name = u1.name)
AND    u1.detected_usages > 0
AND    u1.dbid = (SELECT dbid FROM v$database)
ORDER BY name
/

CLEAR COMPUTES COLUMNS

PROMPT

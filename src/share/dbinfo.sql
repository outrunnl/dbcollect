-----------------------------------------------------------------------------
-- Title       : dbinfo.sql
-- Description : collect database information
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-----------------------------------------------------------------------------
define dbinfo_version = '1.1.0' -- Set version
-----------------------------------------------------------------------------
-- Usage: @dbinfo
-- Requires: Oracle database >= 11.2
--
-- This script collects database info about the current connected database
--
-- Results are printed on screen 140 characters wide, separator '|' is used
-- for easy parsing by automated scripts. Sizes in Mibibytes (MiB) unless
-- otherwise specified.
--
-- Created by Bart Sjerps (bart<at>outrun.nl) with code snippets from
-- various people, including Graham Thornton, Asad Samdani and others.
--
-- This script uses only SELECT and SQL*Plus formatting/reporting statements,
-- will not modify (update) any tables and therefore is safe to use on
-- production systems.
-- 
-- Revision history:
-- 1.0   - first version
-- 1.0.1 - Added TAB OFF to avoid messed up formatting (Bart Sjerps)
-----------------------------------------------------------------------------
-- Get spool filename, ignore if not set
column 1 new_value 1 noprint
select '' "1" from dual where rownum = 0;
define spoolpath = &1 "OFF"
undef 1

SPOOL &spoolpath

-- Enable to get | as separator (for script parsing)
set colsep '|'
set tab off
CLEAR COLUMNS COMPUTES BREAKS

set feedback off verify off heading on lines 140 pages 999 trims on
-- set emb on
alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';

COL MIB         FORMAT 999,999,990.99
COL KIB         FORMAT 90.9
COL PCT         FORMAT 990.99
COL METRIC      FORMAT A20        HEAD 'Metric'
COL VALUE       FORMAT A60        HEAD 'Value'
COL NUMVAL      FORMAT 99,999,990 HEAD 'Value'
COL FILENAME    FORMAT A90        HEAD 'Filename'
COL PATH        FORMAT A60        HEAD 'Path'
COL FILETYPE    FORMAT A20        HEAD 'Filetype'
COL SEGTYPE     FORMAT A20        HEAD 'Segtype'

COL DBFILES     FORMAT 9990       HEAD 'Files'
COL FILES       FORMAT 999,990    HEAD 'Files'
COL OBJECTS     FORMAT 999,990    HEAD 'Objects'

COL TS_NAME     FORMAT A25        HEAD 'Tablespace'
COL TS_TYPE     FORMAT A7         HEAD 'Type'
COL DG_NAME     FORMAT A30        HEAD 'Diskgroup'
COL DISKNAME    FORMAT A16        HEAD 'Disk name'
COL AU_SIZE     FORMAT 99         HEAD 'AU'
COL FEATURE     FORMAT A55        HEAD 'Feature'
COL USAGES      FORMAT 9,999      HEAD 'Usage'
COL STATE       FORMAT A7         HEAD 'Mounted'
COL MIRRORS     FORMAT 9          HEAD 'Mir'
COL COMPR       FORMAT A6         HEAD 'Compr'
COL ENCR        FORMAT A6         HEAD 'Encr'
COL PARAMETER   FORMAT A40        HEAD 'Parameter'
COL SIZE_MB     LIKE MIB          HEAD 'Size'
COL ALLOCATED   LIKE MIB          HEAD 'Allocated'
COL USED_MB     LIKE MIB          HEAD 'Used'
COL FREE_MB     LIKE MIB          HEAD 'Free'
COL PCT_USED    LIKE PCT          HEAD 'Used %'
COL BLOCKSIZE   LIKE KIB          HEAD 'BS(K)'

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DBINFO version &dbinfo_version
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

WITH stats as (select stat_name name
  , decode(stat_name, 'PHYSICAL_MEMORY_BYTES', round(value/1024/1024), value) value
  FROM  dba_hist_osstat
  WHERE snap_id = (select max(snap_id) from dba_hist_osstat)
)
select           'dbname' metric,  name value               from v$database
union all select 'hostname',       host_name                from v$instance
union all select 'report date',    to_char(sysdate)         from dual
union all select 'dbid',           to_char(dbid)            from v$database
union all select 'instance',       instance_name            from v$instance
union all select 'version',        version                  from v$instance
union all select 'inst_number',    to_char(instance_number) from v$instance
union all select 'product',        product                  from product_component_version 
                                                            where product like 'Oracle%'
union all select 'unique_name',    db_unique_name           from v$database
union all select 'startup',        to_char(startup_time)    from v$instance
union all select 'uptime (days)',  to_char(round(sysdate - startup_time,2)) from v$instance
union all select 'rac',            parallel                 from v$instance
union all select 'inst_role',      instance_role            from v$instance
union all select 'log_mode',       log_mode                 from v$database
union all select 'force_logging',  force_logging            from v$database
union all select 'prot_mode',      protection_mode          from v$database
union all select 'db_role',        database_role            from v$database
union all select 'flashback',      flashback_on             from v$database
union all select 'memory',         to_char(value)           from stats where name = 'PHYSICAL_MEMORY_BYTES'
union all select 'sockets',        to_char(value)           from stats where name = 'NUM_CPU_SOCKETS'
union all select 'cores',          to_char(value)           from stats where name = 'NUM_CPU_CORES'
union all select 'lcpus',          to_char(value)           from stats where name = 'NUM_CPUS'
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE SIZE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF DBFILES SIZE_MB ON REPORT

WITH SIZES AS (
  select 'controlfiles' ftype, count(name) dbfiles, sum(block_size*file_size_blks) bytes from v$controlfile union all
  select 'datafiles',          count(file_id),      sum(bytes) bytes from dba_data_files union all
  select 'tempfiles',          count(file_id),      sum(bytes) from dba_temp_files union all
  select 'redologs',           sum(members),        sum(bytes) from v$log
)
SELECT ftype FILETYPE, DBFILES, bytes/1024/1024 SIZE_MB from SIZES
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CORE DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

WITH FILES AS (
  SELECT 'CONTROLFILE' type, block_size*file_size_blks bytes, block_size bs, name from v$controlfile UNION ALL
  SELECT 'DATAFILE', bytes, block_size, name  from v$datafile UNION ALL
  SELECT 'TEMPFILE', bytes, block_size, name  from v$tempfile UNION ALL
  SELECT 'REDOLOG',  bytes, blocksize, member from v$log a JOIN v$logfile b ON a.Group#=b.Group#
)
SELECT TYPE FILETYPE
, BS/1024 BLOCKSIZE
, BYTES/1024/1024 SIZE_MB
, NAME FILENAME
FROM FILES
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ADDITIONAL DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT
-- TBD: Backup sets?
-- select file_type, status, compressed, count(fname) files, sum(bytes)/1024/1024 MIB from v$backup_files group by file_type, status, compressed;

WITH STATS AS (select 
    decode(file_type,'PIECE','BACKUP PIECE',file_type) filetype
  , compressed
  , bytes 
  FROM v$backup_files 
  WHERE STATUS='AVAILABLE' AND file_type IN ('COPY','PIECE','ARCHIVED LOG')
  UNION ALL
  SELECT 'FLASHBACKLOG' type, '', bytes FROM v$flashback_database_logfile 
)
SELECT filetype, compressed compr, sum(bytes)/1024/1024 size_mb, count(*) files FROM stats
GROUP BY filetype, compressed
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT TABLESPACES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF ALLOCATED FREE_MB USED_MB ON REPORT

WITH DF AS (SELECT tablespace_name
  , (select count(*) from dba_segments where dba_segments.tablespace_name = DF.tablespace_name) objects
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
union all
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


PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT SEGMENT SIZES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF OBJECTS SIZE_MB ON REPORT

SELECT segment_type segtype, count(*) objects, sum(bytes)/1024/1024 size_mb
FROM dba_segments 
GROUP BY segment_type
ORDER BY size_mb
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISK GROUPS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT name dg_name
, allocation_unit_size/1024/1024 au_size
-- , decode(state,'MOUNTED','Y','CONNECTED','Y','DISMOUNTED','N','E') state
, decode(type, 'EXTERN',  1, 'NORMAL',    2 ,'HIGH',       3 , 0 ) mirrors
, (total_mb - free_mb) used_mb
, free_mb              free_mb
, total_mb             allocated
, ROUND((1- (free_mb / nullif(total_mb,0)))*100, 2) PCT_USED
FROM v$asm_diskgroup
ORDER BY name
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISKS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT  disk.name as DISKNAME
-- decode(dg.name,NULL,'-',dg.name) AS dg_name
--  lpad(decode(disk.name,NULL,'-',disk.name),12) AS DISKNAME
, (disk.total_mb - disk.free_mb)/1024 as used_mb
, disk.free_mb/1024 as free_mb
, disk.os_mb/1024 AS allocated
, 100*(disk.total_mb - disk.free_mb)/nullif(disk.total_mb,0) as pct_used
-- , substr(header_status,1,9) as header
-- , disk.state
, path
FROM gv$asm_disk disk
LEFT OUTER JOIN v$asm_diskgroup dg ON disk.group_number = dg.group_number AND dg.group_number <> 0
JOIN v$instance ON inst_id=instance_number
ORDER BY disk.name,path
/

CLEAR COMPUTES

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INIT PARAMETERS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Non-null/non-default init parameters

SELECT name parameter, value FROM v$parameter
WHERE isdefault = 'FALSE' AND value IS NOT NULL
ORDER BY name
/

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE FEATURE USAGE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SELECT name feature, detected_usages usages
FROM   dba_feature_usage_statistics 
WHERE  detected_usages > 0
AND    dbid = (SELECT dbid FROM v$database)
ORDER BY name
/
PROMPT

-----------------------------------------------------------------------------
-- Cleanup & reset
-----------------------------------------------------------------------------

CLEAR COLUMNS COMPUTES BREAKS
set colsep ' '

SPOOL OFF

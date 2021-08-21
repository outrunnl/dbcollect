
-- 
--
-- script to report database capacity
--
-- this script generates a capacity report
-- for the current database.  this script is designed
-- for 10g databases.
-- 
-- script will fail on older systems
--
-- connect as any user with access to the DBA Data Dictionary views, such as the SYSTEM account.  
--

set pagesize 9999
set linesize 132
set heading on 
set feedback off
set trims on

column dt      new_value new_dt
column ext     new_value new_ext
column dbname  new_value new_dbname
column insname new_value new_insname

select name||'_' dbname, to_char(sysdate,'YYYYMMDD') dt, '.txt' ext from V$DATABASE;
select instance_name||'_' insname from V$INSTANCE;

spool capacity_&new_dbname&new_insname&new_dt&new_ext

prompt **
prompt database id
prompt **

col name          for a8
col version       for a12
col startup_time  for a15
col log_mode      for a15
col rac           for a3

select
  vd.name,
  vi.version,
  vi.startup_time,
  vd.log_mode,
  vi.parallel RAC
from
  v$database vd,
  v$instance vi
/

prompt **
prompt feature usage
prompt **

COLUMN name  FORMAT A60
COLUMN detected_usages FORMAT 999,999,999,999
COLUMN currently_usaged FORMAT A18

SELECT u1.name,
       u1.detected_usages,
       u1.currently_used,
       u1.version
FROM   dba_feature_usage_statistics u1
WHERE  u1.version = (SELECT MAX(u2.version)
                     FROM   dba_feature_usage_statistics u2
                     WHERE  u2.name = u1.name)
AND    u1.detected_usages > 0
AND    u1.dbid = (SELECT dbid FROM v$database)
ORDER BY name
/

prompt **
prompt patchset detail
prompt **

col comments for a80

select 
  comments 
from dba_registry_history
/

prompt **
prompt controlfile detail
prompt **

col control_file for a80
col cf_size_mb   for 99999.99
col keep         for a10

select /*+ RULE CURSOR_SHARING_EXACT */
  cf.name CONTROL_FILE,
  (cf.block_size*cf.file_size_blks)/1048576 "CF_SIZE_MB",
  keep.value "KEEP"
from
  v$controlfile cf,
  ( select value from v$parameter where name = 'control_file_record_keep_time' ) keep
order by cf.name
/

prompt **
prompt capacity
prompt **

col contents for a15
col tc       for 999999
col bs       for 99999
col fc       for 999999
col size_fmt for a8
col size_gb  for 999999999
col free_fmt for a8
col free_gb  for 999999999
col max_fmt  for a8
col max_gb   for 999999999
col enc      for a4
col cmp      for a8

select
  dts.contents,
  count(*) "TC",
  sum(my_dba_data_files.file_count) "FC",
  max(dts.def_tab_compression) "CMP",
  --
  substr(
    decode(floor(sum(my_dba_data_files.total_size)/1125899906842620),0,
      decode(floor(sum(my_dba_data_files.total_size)/1099511627776),0,
        decode(floor(sum(my_dba_data_files.total_size)/1073741824),0,
          decode(floor(sum(my_dba_data_files.total_size)/1048576),0,
            to_char(sum(my_dba_data_files.total_size)/1024,'999999')||'K',
            to_char(sum(my_dba_data_files.total_size)/1048576,'999999')||'M'),
          to_char(sum(my_dba_data_files.total_size)/1073741824,'9999.9')||'G'),
        to_char(sum(my_dba_data_files.total_size)/1099511627776,'9999.9')||'T'),
      to_char(sum(my_dba_data_files.total_size)/1125899906842620,'9999.9')||'P')
  ,2,7) "SIZE_FMT",
  sum(my_dba_data_files.total_size/1073741824) "SIZE_GB",
  --
  substr(
    decode(floor(sum(my_free_space.total_free_space)/1125899906842620),0,
      decode(floor(sum(my_free_space.total_free_space)/1099511627776),0,
        decode(floor(sum(my_free_space.total_free_space)/1073741824),0,
          decode(floor(sum(my_free_space.total_free_space)/1048576),0,
            to_char(sum(my_free_space.total_free_space)/1024,'999999')||'K',
            to_char(sum(my_free_space.total_free_space)/1048576,'999999')||'M'),
          to_char(sum(my_free_space.total_free_space)/1073741824,'9999.9')||'G'),
        to_char(sum(my_free_space.total_free_space)/1099511627776,'9999.9')||'T'),
      to_char(sum(my_free_space.total_free_space)/1125899906842620,'9999.9')||'P')
  ,2,7) "FREE_FMT",
  sum(my_free_space.total_free_space/1073741824) "FREE_GB",
  --
  substr(
    decode(floor(sum(my_dba_data_files.max_size)/1125899906842620),0,  
      decode(floor(sum(my_dba_data_files.max_size)/1099511627776),0,
        decode(floor(sum(my_dba_data_files.max_size)/1073741824),0,
          decode(floor(sum(my_dba_data_files.max_size)/1048576),0,
            to_char(sum(my_dba_data_files.max_size)/1024,'999999')||'K',
            to_char(sum(my_dba_data_files.max_size)/1048576,'999999')||'M'),
          to_char(sum(my_dba_data_files.max_size)/1073741824,'9999.9')||'G'),
        to_char(sum(my_dba_data_files.max_size)/1099511627776,'9999.9')||'T'),
      to_char(sum(my_dba_data_files.max_size)/1125899906842620,'9999.9')||'P')
  ,2,7) "MAX_FMT",
  sum(my_dba_data_files.max_size/1073741824) "MAX_GB",
  dts.block_size "BS"
from dba_tablespaces dts, 
  (
  select
    tablespace_name,
    count(file_id) file_count,
    sum(bytes) total_size,
    sum(decode(autoextensible,'YES',greatest(bytes,maxbytes),bytes)) max_size
  from dba_data_files 
  group by tablespace_name
  union all
  select
    tablespace_name,
    count(file_id) file_count,
    sum(bytes) total_size,
    sum(decode(autoextensible,'YES',greatest(bytes,maxbytes),bytes)) max_size
  from dba_temp_files 
  group by tablespace_name 
  ) my_dba_data_files, 
  (
    select
      dfs.tablespace_name tablespace_name,
      sum(dfs.bytes) total_free_space
    from dba_free_space dfs
    group by tablespace_name
    union all
    select
      dts.tablespace_name, 0
    from dba_tablespaces dts
    where not exists ( 
      select 1 
      from dba_free_space dfs 
      where 1=1 
      and dfs.tablespace_name = dts.tablespace_name 
    )
  ) my_free_space
where 1=1
--and cts.contents not in ('TEMPORARY')
and dts.tablespace_name = my_dba_data_files.tablespace_name(+)
and dts.tablespace_name = my_free_space.tablespace_name(+)
group by 
  dts.contents, 
  dts.block_size,
  dts.def_tab_compression
/

prompt **
prompt block change tracking summary
prompt **

select
  substrb(decode(ascii(substrb(bc.filename,57,1)),NULL,bc.filename,
    substrb(bc.filename,1,6)||'..'||
    substrb(bc.filename,greatest(length(bc.filename)-48,0),49)),1,57) BCT_FILE,
  substrb(decode(floor(bc.bytes/1099511627776),0,
    decode(floor(bc.bytes/1073741824),0,
      decode(floor(bc.bytes/1048576),0,
        to_char(bc.bytes/1024,'999999')||'K',
        to_char(bc.bytes/1048576,'999999')||'M'
      ),
      to_char(bc.bytes/1073741824,'9999.9')||'G'
    ),
    to_char(bc.bytes/1099511627776,'9999.9')||'T'
   ),2,7) "SIZE"
from v$block_change_tracking  bc
/

prompt **
prompt dataguard detail
prompt **

select protection_mode, protection_level from v$database;

prompt **
prompt flash recovery area summary
prompt **

col flash_recovery_area for a52
col fra_space_gb        for 9999999.99

select /*+ RULE CURSOR_SHARING_EXACT */
  rf.name FLASH_RECOVERY_AREA,
  sum(rf.space_limit/1073741824) FRA_SIZE_GB,
  substr(decode(floor(sum(rf.space_limit)/1099511627776),0,
    decode(floor(sum(rf.space_limit)/1073741824),0,
      decode(floor(sum(rf.space_limit)/1048576),0,
        to_char(sum(rf.space_limit)/1024,'999999')||'K',
        to_char(sum(rf.space_limit)/1048576,'999999')||'M'),
      to_char(sum(rf.space_limit)/1073741824,'9999.9')||'G'),
    to_char(sum(rf.space_limit)/1099511627776,'9999.9')||'T'),2,7) "FRA_SIZE_FMT"
from
  v$recovery_file_dest rf
group by rf.name
/

prompt **
prompt redolog review
prompt **

col log_file    for a60
col lf_size_fmt for a11
col blocksize   for 9999

select /*+ RULE CURSOR_SHARING_EXACT */
  lf.member LOG_FILE,
  log.bytes/1048576 LF_SIZE_MB,
  substrb(decode(floor(log.bytes/1048576),0,
    to_char(log.bytes/1024,'999999')||'K',
    to_char(log.bytes/1048576,'999999')||'M'),2,7) LF_SIZE_FMT,
  log.group# "GROUP",
  log.members "MEMBERS"
from
  v$logfile lf,
  v$log log
where 1=1
and lf.group# = log.group#
order by log.group#, log.members
/

prompt **
prompt show log generation
prompt **

col logs_mb for 999999999

select 
  trunc(completion_time) time, 
  sum(blocks*block_size)/1048576 logs_mb
from gv$archived_log 
where completion_time > sysdate-90
group by trunc(completion_time)
order by 1
/

prompt **
prompt show rman backups
prompt **

col lvl          format 99
col pieces       format 99999
col complete     format a9
col device       format a8
col elapsed      format 9999999
col taken        format a9

col cmp          format a3
col enc          format a3 

col inrate_mb/s  format 99999.99
col outrate_mb/s format 99999.99
col input_gb     format 9999999.99
col output_gb    format 9999999.99
col arch_gb      format 9999999.99

select
  vd.dbid,
  vd.name,
  bs.incremental_level LVL,
 -- bsd.backup_type,
  bsd.completion_time complete,
  -- bsd.pieces,
  bs.elapsed_seconds elapsed,
  bsd.time_taken_display taken,
 -- bsd.block_size,
  bsd.device_type device,
  bsd.compressed CMP,
  --bsd.encrypted ENC,
  bsd.original_inprate_bytes/1048576 "INRATE_MB/S",
  bsd.output_rate_bytes/1048576 "OUTRATE_MB/S",
  bsd.original_input_bytes/1073741824 INPUT_GB,
  bsd.output_bytes/1073741824 OUTPUT_GB,
  bad.filesize/1073741824 ARCH_GB
from
  v$database vd,
  v$backup_set bs,
  v$backup_set_details bsd,
  v$backup_archivelog_details bad
where 1=1
and bs.recid = bsd.recid
and bs.stamp = bsd.stamp
and bsd.session_key = bad.session_key(+)
and bsd.session_recid = bad.session_recid(+)
and bsd.session_stamp = bad.session_stamp(+)
and bsd.completion_time > sysdate-90
order by
  bsd.completion_time
/

prompt **
prompt show key parameters
prompt **

col inst_id for 9999999
col name for a30
col value for a30

select
  inst_id,
  name,
  value
from gv$parameter
where name in (
  'backup_tape_io_slaves',
  'db_file_multiblock_read_count',
  'db_writer_processes',
  'dbwr_io_slaves',
  'disk_asynch_io',
  'filesystemio_options',
  'memory_max_target',
  'memory_target', 
  'pga_aggregate_limit',
  'pga_aggregate_target',
  'processes',
  'sga_max_size',
  'sga_target',  
  'tape_asynch_io',
  'use_large_pages'
)
order by 1,2,3
/

prompt **
prompt show system stats
prompt **

select * from sys.aux_stats$
/

spool off










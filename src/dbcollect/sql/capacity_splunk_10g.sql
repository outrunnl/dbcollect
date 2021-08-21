
-- 
-- Dell Technologies
-- Oracle capacity script for Oracle 10g
--
-- original version by Thiago Ferreira
-- modifications for 12c and 10g by Graham Thornton
--

-- Starts data space usage data collection 

prompt Reading Disk Space Usage Data...

set trims on
set term  off
set pages 0
set head  off
set lines 250 
set feed  off

col storage_filename   new_val storage_filename

alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';
set verify off

select 
  'dellemc_diskusage_'||NAME||'_'||DBID||'.dsk' storage_filename
from  V$DATABASE d;

spool '&&storage_filename'

  select 
    '##HDR##;TIMESTAMP;CUSTOMER_NAME;DB_NAME;DBID;KEY;GB'
  from dual
  union all
  select 
    '##REC##;'||
    to_char(sysdate,'DD-MM-YYYY HH24:MI:SS')||
    ';Y0X0X0X0X0Z;'||
    NAME||';'||
    to_char(DBID)||';'||
    replace(KEY,' ','_')||';'||
    ltrim(to_char(GB,'99999990.999')) 
  from (
    --
    -- count all allocated space
    --
    select 
      'ALLOCATED' KEY,
      sum(GB) GB 
    from
    (
      select 'DATAFILES' KEY, sum(bytes/1073741824) GB from dba_data_files
      union all
      select 'TEMPFILES' KEY, sum(bytes/1073741824) GB from dba_temp_files
      union all
      select 'LOGFILE' KEY, sum(bytes/1073741824) GB from gv$log
    )
    --
    union all
    --
    -- count all used space
    --
    select 'USED' KEY, sum(bytes/1073741824) GB from dba_segments
    --
    union all
    --
    -- report the quanity of archive from the last 7 days
    --
    select 
      'ARCHIVELOG_7DAY' KEY, 
      nvl(sum(blocks*block_size)/1073741824,0) logs_gb
    from gv$archived_log 
    where completion_time > sysdate-7
    --
    union all
    --
    -- report the amount of space allocated to the FRA
    --
    select
      'FRA_ALLOCATED' KEY,
      sum(SPACE_LIMIT/1073741824) GB
    from v$recovery_file_dest
    --
    union all
    --
    -- report the amount of space USED by the FRA
    --
    select
      'FRA_USED' KEY,
       sum(SPACE_USED/1073741824) GB
    from v$recovery_file_dest
  ), v$database
/

spool off

set term on

-- 
-- Dell Technologies
-- Oracle capacity script for Oracle 11g
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
    -- count compress or encrypted
    -- as this will not compress well
    --
    select 
      KEY,
      GB 
    from
    (
      select 'ALLOCATED_ENCRYPTED' KEY, nvl(sum(cdf.bytes/1073741824),0) GB 
      from dba_data_files cdf, dba_tablespaces cts
      where 1=1
        and cdf.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'YES'
        and cts.compress_for is null
      union all
      select 'ALLOCATED_COMPRESSED' KEY, nvl(sum(nvl(cdf.bytes,0)/1073741824),0) GB 
      from dba_data_files cdf, dba_tablespaces cts
      where 1=1
        and cdf.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'NO'
        and cts.compress_for is not null
      union all
      select 'ALLOCATED_ENCRYPTED_AND_COMPRESSED' KEY, nvl(sum(nvl(cdf.bytes,0)/1073741824),0) GB 
      from dba_data_files cdf, dba_tablespaces cts
      where 1=1
        and cdf.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'YES'
        and cts.compress_for is not null
    ) where gb>0
    --
    union all
    --
    -- count all used space
    --
    select 'USED' KEY, sum(bytes/1073741824) GB from dba_segments
    --
    -- count used space that is compressed and or encrypted
    --
    union all
    --
    select
      KEY,
      GB
    from (
      select 'USED_ENCRYPTED' KEY, nvl(sum(csg.bytes/1073741824),0) GB 
      from dba_segments csg, dba_tablespaces cts
      where 1=1
        and csg.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'YES'
        and cts.compress_for is null
      union all
      select 'USED_COMPRESSED' KEY, nvl(sum(csg.bytes/1073741824),0) GB 
      from dba_segments csg, dba_tablespaces cts
      where 1=1
        and csg.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'NO'
        and cts.compress_for is not null
      union all
      select 'USED_ENCRYPTED_AND_COMPRESSED' KEY, nvl(sum(csg.bytes/1073741824),0) GB 
      from dba_segments csg, dba_tablespaces cts
      where 1=1
        and csg.tablespace_name = cts.tablespace_name
        and upper(cts.encrypted) = 'YES'
        and cts.compress_for is not null
    ) where gb>0
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
    --
    union all
    --
    -- tables that are compressed
    --
    select 
      tb.segment_type||' '||compress_for||' COMPRESSION' KEY,
      sum(s.bytes/1073741824) GB
    from
    (
    select 
      owner,
      table_name segment_name,
      '' partition_name,
      'TABLE' segment_type,
       compression,
       compress_for
    from 
      dba_tables     
    where 
      compress_for is not null
    ) TB,
    dba_segments S
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    --
    union all
    --
    -- table partitions that are compressed
    --
    select 
      tb.segment_type||' '||compress_for||' COMPRESSION' KEY,
      sum(s.bytes/1024/1024/1024) GB
    from
    (
    select 
      table_owner owner,
      table_name segment_name,
      partition_name,
      'TABLE PARTITION' segment_type,
      compression,
      compress_for
    from dba_tab_partitions     
    where compress_for is not null
    ) TB,
    dba_segments S
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.partition_name = tb.partition_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    --
    union all
    --
    -- table sub partitions that are compressed
    --
    select 
    tb.segment_type||' '||compress_for||' COMPRESSION' KEY,
    sum(s.bytes/1024/1024/1024) GB
    from
    (
    select 
      table_owner owner   ,
      table_name segment_name,
      subpartition_name partition_name,
      'TABLE SUBPARTITION' segment_type,
      compression      ,
      compress_for
    from dba_tab_subpartitions     
    where compress_for is not null
    ) tb,
    dba_segments s
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.partition_name = tb.partition_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    --
    union all
    --
    -- index that are compressed
    --
    select 
    tb.segment_type||' COMPRESSION' KEY,
    sum(s.bytes/1024/1024/1024) GB
    from
    (
    select
      owner,
      index_name segment_name,
      '' partition_name,
      'INDEX' segment_type,
      compression,
      '' compress_for
    from dba_indexes     
    where compression = 'ENABLED'
    ) TB,
    dba_segments S
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    --
    union all
    --
    -- index partitions that are compressed
    --
    select 
    tb.segment_type||' '||compress_for||' COMPRESSION' KEY,
    sum(s.bytes/1024/1024/1024) GB
    from
    (
    select 
      index_owner owner   ,
      index_name segment_name,
      partition_name,
      'INDEX PARTITION' segment_type,
      compression         ,
      '' compress_for
    from dba_ind_partitions     
    where compression = 'ENABLED'
    ) TB,
    dba_segments S
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.partition_name = tb.partition_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    --
    union all
    --
    -- index sub partitions that are compressed
    --
    select 
    tb.segment_type||' '||compress_for||' COMPRESSION' KEY,
    sum(s.bytes/1024/1024/1024) GB
    from
    (
    select 
      index_owner owner,
      index_name segment_name,
      subpartition_name partition_name,
      'INDEX SUBPARTITION' segment_type,
      compression,
      '' COMPRESS_FOR
    from dba_ind_subpartitions     
    where compression = 'enabled'
    ) TB,
    dba_segments S
    where 1=1
    and s.owner = tb.owner
    and s.segment_name = tb.segment_name
    and s.partition_name = tb.partition_name
    and s.segment_type = tb.segment_type
    group by tb.segment_type, compress_for
    ), 
  v$database v
/

spool off

set term on

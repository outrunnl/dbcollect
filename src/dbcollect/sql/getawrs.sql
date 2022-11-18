-------------------------------------------------------------------------------
-- Title       : getawrs.sql
-- Description : generate SQL to retrieve AWR reports
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Parameters  : days = amount of days for which to collect data
--               offset = days to timeshift back. 0 = until and including today
--               local = Y: generate AWRS for this instance only
-- Output      : AWR snapshot parameters in CSV format
-- ----------------------------------------------------------------------------

-- define days   = 10
-- define offset = 0
-- define local  = Y|N

SET tab off feedback off verify off heading off lines 1000 pages 0 trims on
ALTER SESSION SET nls_timestamp_format='YYYYMMDD_HH24MI';
ALTER SESSION SET nls_date_format='YYYYMMDD_HH24MI';
WHENEVER SQLERROR EXIT SQL.SQLCODE

WITH INFO AS (SELECT dbid
  , interval '&days'   DAY(3) ndays
  , interval '&offset' DAY(3) offset
  , interval '1'       DAY    oneday
  , '&local'                  local
  , (SELECT MAX(end_interval_time) FROM dba_hist_snapshot) max_time
  , (SELECT instance_number FROM v$instance)               local_inst
  FROM v$database)
SELECT dbid
  || ',' || instance_number
  || ',' || prev_id
  || ',' || snap_id
  || ',' || begintime
  || ',' || endtime
FROM (SELECT snap_id
  , instance_number
  , dbid
  , startup_time
  , end_interval_time                                                           endtime
  , lag(end_interval_time) over (PARTITION BY instance_number ORDER BY snap_id) begintime
  , lag(snap_id)           over (PARTITION BY instance_number ORDER BY snap_id) prev_id
  , lag(startup_time)      over (PARTITION BY instance_number ORDER BY snap_id) last_startup_time
  FROM dba_hist_snapshot
  WHERE snap_flag = 0)                                       -- only auto-generated snaps
JOIN INFO USING (dbid)                                       -- ignore old data from other DBIDs
WHERE startup_time = last_startup_time                       -- skip over db restarts
  AND endtime   >= trunc(max_time + oneday - offset - ndays) -- starting time
  AND begintime <  trunc(max_time + oneday - offset)         -- ending time
  -- AND endtime   >  begintime + interval '10' MINUTE       -- ignore reports with less than 10 minute interval
  AND (instance_number = local_inst OR local!='Y')           -- optionally filter AWRs from other RAC nodes
ORDER BY snap_id, instance_number
/

-------------------------------------------------------------------------------
-- Title       : getawrs.sql
-- Description : generate SQL to retrieve AWR reports
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Parameters  : days:     amount of days ago to start collect period
--               end_days: amount of days before current to stop collect period
--               inc_rac:  include snaps for other instances (RAC)
--               inc_stby: include snaps for other DBIDs (realime standby DBs)
--               inc_pack: include snaps for which diag/tuning packs are disabled
-- Output      : AWR snapshot parameters in CSV format
-- ----------------------------------------------------------------------------

-- defaults:
-- define days     = 10
-- define end_days = 0
-- define inc_rac  = 1
-- define inc_stby = 1
-- define inc_pack = 0

SET tab off feedback off verify off heading off lines 1000 pages 0 trims on
ALTER SESSION SET nls_timestamp_format='YYYYMMDD_HH24MI';
ALTER SESSION SET nls_date_format='YYYYMMDD_HH24MI';
WHENEVER SQLERROR EXIT SQL.SQLCODE

WITH INFO AS (
  SELECT (SELECT MAX(end_interval_time) FROM dba_hist_snapshot) max_time
  , interval '&days'     DAY(3) ndays
  , interval '&end_days' DAY(3) end_days
  , interval '1'         DAY    oneday
  , '&inc_rac'  inc_rac
  , '&inc_stby' inc_stby
  , '&inc_pack' inc_pack
  FROM dual
)
SELECT dbid
  || ',' || inst_num
  || ',' || prev_id
  || ',' || snap_id
  || ',' || begintime
  || ',' || endtime
FROM (SELECT dbid
  , snap_id
  , snap_flag
  , instance_number inst_num
  , startup_time
  , end_interval_time endtime
  , lag(end_interval_time) over (PARTITION BY dbid, instance_number ORDER BY snap_id) begintime
  , lag(snap_id)           over (PARTITION BY dbid, instance_number ORDER BY snap_id) prev_id
  , lag(startup_time)      over (PARTITION BY dbid, instance_number ORDER BY snap_id) last_startup_time
  FROM dba_hist_snapshot
), info
WHERE prev_id IS NOT NULL                              -- ignore FIRST
  AND startup_time = last_startup_time                 -- skip over db restarts (does not work for standby dbs!)
  AND endtime   >= trunc(max_time + oneday - ndays)    -- starting time: ndays BEFORE last snap
  AND begintime <  trunc(max_time + oneday - end_days) -- ending time: offset BEFORE last snap
  AND endtime - begintime > interval '8'  MINUTE       -- ignore reports with less than 8 minute interval
  AND endtime - begintime < interval '90' MINUTE       -- ignore reports with more than 90 minute INTERVAL
  AND snap_flag NOT IN (1,2)                           -- ignore manual AND imported snaps (note: standby is always 17)
  -- optional filters
  AND (inc_rac  = 1 OR inst_num = (SELECT instance_number FROM v$instance)) -- include other RAC nodes
  AND (inc_stby = 1 OR dbid = (SELECT dbid FROM v$database))                -- include standby snapshots
  AND (inc_pack = 1 OR snap_flag NOT IN (4,5))                              -- include when diag/tuning packs disabled
ORDER BY dbid, snap_id, inst_num
/

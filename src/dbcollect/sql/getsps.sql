-------------------------------------------------------------------------------
-- Title       : getsps.sql
-- Description : generate SQL to retrieve Statspack reports
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Parameters  : days = amount of days for which to collect data
--               offset = days to timeshift back. 0 = until and including today
-- Output      : Statspack snapshot parameters in CSV format
-- ----------------------------------------------------------------------------

SET tab off feedback off verify off heading off lines 1000 pages 0 trims on
ALTER SESSION SET nls_timestamp_format='YYYYMMDD_HH24MI';
ALTER SESSION SET nls_date_format='YYYYMMDD_HH24MI';
WHENEVER SQLERROR EXIT SQL.SQLCODE

WITH INFO AS (SELECT dbid
  , interval '&days'   DAY(3) ndays
  , interval '&offset' DAY(3) offset
  , interval '1'       DAY    oneday
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
  , lag(snap_time) over (PARTITION BY instance_number ORDER BY snap_id)    begintime
  , snap_time                                                              endtime
  , lag(snap_id) over (PARTITION BY instance_number ORDER BY snap_id)      prev_id
  , lag(startup_time) over (PARTITION BY instance_number ORDER BY snap_id) last_startup_time
  , (SELECT MAX(snap_time) FROM stats$snapshot)                            max_time
  FROM stats$snapshot)
JOIN INFO USING (dbid)                                       -- ignore old data from other DBIDs
WHERE startup_time = last_startup_time                       -- skip over db restarts
  AND endtime   >= trunc(max_time + oneday - offset - ndays) -- starting time
  AND begintime <  trunc(max_time + oneday - offset)         -- ending time
  AND endtime   >  begintime + interval '10' MINUTE          -- ignore reports with less than 10 minute interval
ORDER BY snap_id, instance_number
/

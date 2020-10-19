-------------------------------------------------------------------------------
-- Title       : genawr.sql
-- Description : generate SQL to retrieve AWR reports
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-- Parameters  : days = amount of days for which to collect data
--               offset = days to timeshift back. 0 = until and including today
-- ----------------------------------------------------------------------------
-- This script is intended to be called from Python to expand the
-- days and offset parameters, Script will fail otherwise.
-- Do not run the generated script UNLESS you have a diagnostics pack license
-- Reports are placed in the CURRENT directory (cd to the right dir first)
-- ----------------------------------------------------------------------------

define days   = {0}
define offset = {1}

set pagesize 0 lines 999 tab off verify off feed off
ALTER SESSION SET nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';

SELECT 'host echo Generating AWR reports. Please wait ...' || chr(10)
  || 'set echo off head off feed off trims on lines 32767 pages 50000' || chr(10)
  || 'alter session set nls_date_language=american;' header FROM dual;

WITH reports AS (SELECT snap_id
  , instance_number i
  , dbid
  , startup_time
  , begin_interval_time begintime
  , end_interval_time endtime
  , lag(snap_id,1) over (order by instance_number,snap_id) prev_id
  , (SELECT MAX(end_interval_time) FROM dba_hist_snapshot) max_time
  , lag(startup_time,1) over (order by instance_number,snap_id) last_startup_time
  FROM dba_hist_snapshot),
  INFO AS (SELECT dbid
  , name
  , interval '&days'   DAY(3) ndays
  , interval '&offset' DAY(3) offset
  , interval '1'       DAY oneday
  FROM v$database)
SELECT 'set term on escape off' || chr(10)
  || 'prompt creating awr report for ' || name || ', instance ' || i || ', snap id ' || snap_id || ' (' || endtime || ')' || chr(10)
  || 'set term off' || chr(10)
  || 'spool ' || name || '_awrrpt_' || i || '_' || prev_id  || '_' || snap_id || '.html' || chr(10)
  || 'select output from table (dbms_workload_repository.awr_report_html('
  || reports.dbid || ','
  || i            || ','
  || prev_id      || ','
  || snap_id      || '));' || chr(10)
  || 'spool off'
FROM reports
JOIN info on reports.dbid = info.dbid                      -- ignore data from other DB
WHERE startup_time = last_startup_time                     -- skip over db restarts
AND endtime   >= trunc(max_time + oneday - offset - ndays) -- starting time
AND begintime <  trunc(max_time + oneday - offset)         -- ending time
ORDER BY snap_id, i
/

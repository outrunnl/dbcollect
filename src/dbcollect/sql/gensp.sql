-------------------------------------------------------------------------------
-- Title       : gensp.sql
-- Description : generate SQL to retrieve Statspack reports
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-- Parameters  : days = amount of days for which to collect data
--               offset = days to timeshift back. 0 = until and including today
-- ----------------------------------------------------------------------------
-- This script is intended to be called from Python to expand the
-- days and offset parameters, Script will fail otherwise.
-- The resulted SQL script does not require a license but Statspack must be
-- configured.
-- Reports are placed in the CURRENT directory (cd to the right dir first)
-- ----------------------------------------------------------------------------

define days   = {}
define offset = {}

set pagesize 0 lines 999 tab off verify off feed off
ALTER SESSION SET nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';

WHENEVER SQLERROR EXIT SQL.SQLCODE

SELECT 'host echo Generating AWR reports. Please wait ...' || chr(10)
  || 'set echo off head off feed off trims on lines 9999 pages 50000' || chr(10)
  || 'alter session set nls_date_language=american;' header from dual;

WITH reports AS (SELECT snap_id
  , instance_number i
  , dbid
  , startup_time
  , lag(snap_time,1) over (order by instance_number,snap_id) begintime
  , snap_time endtime
  , lag(snap_id,1) over (order by instance_number,snap_id) prev_id
  , (SELECT MAX(snap_time) FROM stats$snapshot) max_time
  , lag(startup_time,1) over (order by instance_number,snap_id) last_startup_time
  FROM STATS$SNAPSHOT),
  INFO AS (SELECT dbid
  , name
  , interval '&days'   DAY ndays
  , interval '&offset' DAY offset
  , interval '1'       DAY oneday
  FROM v$database)
SELECT 'set term off escape off'     || chr(10)
    || 'define begin_snap='          || prev_id || chr(10)
    || 'define end_snap='            || snap_id || chr(10)
    || 'define report_name='         || name    || '_' || i
    || '_statspack_'                 || prev_id || '_' || snap_id
    || '.txt'                        || chr(10)
    || '@?/rdbms/admin/spreport'     || chr(10)
FROM reports
JOIN info on reports.dbid = info.dbid                      -- ignore data from other DB
WHERE startup_time = last_startup_time                     -- skip over db restarts
AND endtime   >= trunc(max_time + oneday - offset - ndays) -- starting time
AND begintime <  trunc(max_time + oneday - offset)         -- ending time
ORDER BY snap_id
/

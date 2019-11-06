-----------------------------------------------------------------------------
-- Title       : collect-awr.sql
-- Description : collect AWR and other database information
-- Original    : Graham Thornton (oraclejedi@gmail.com)
-- Updates     : Bart Sjerps <bart@outrun.nl>
-- Version     : 1.7
-- License     : GPLv3+
-----------------------------------------------------------------------------
-- Usage: @awr-collect [days] [offset]
-- Parameters:
--   days:   amount of days to collect (default 8)
--   offset: shift collect period N days back (default 0 = include today's reports)
--
-- Requires:
-- * Oracle 11g release 1 or higher
-- * zip and unzip in $ORACLE_HOME/bin
-- * AWR license (detected from dba_feature_usage_statistics)
-- * Some free space in current and /tmp directory
-- * privileges to access the performance views, such as the SYSTEM account
-- * AWR retention > 1 week (10080 minutes), interval max 60 minutes (1 hour)
--
-- This script generates AWR reports in html format.
-- Default is 7 days of snapshots starting 8 days ago,
-- including yesterday. The output is a zip file containing the generated reports.
-- Both temp files and the final zip file are created in the current directory,
-- temp files are cleaned up after successful execution.
-- When using a remote connection, the AWR reports are created on the local
-- system.
--
-- Please note that the use of AWR requires an optional license:
-- The script will check if AWR has been used before, otherwise it fails with
-- an error.
-- 
-- ONLY USE THIS SCRIPT IF YOU HAVE THE RESPECTIVE LICENSE -
-- Otherwise use the STATSPACK script.  

-- Update feature usage: EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);
--
-- Modifications (Bart Sjerps <bart@outrun.nl>):
--
-- * Removed data space and usage collection part (use dbinfo.sql to do that)
-- * Cleaned up code
-- * Added script parameters, @run awr_collect.sql [days] (default 7)
-- * Moving files to zip instead of adding (cleaning up temp html files)
-- * Deleting temp sql script after we're done
-- * Changed AWR filenames to include DB name
-- * Abort if AWR interval >60 or retention < 1 week
-- * Automatically check if AWR is used before (thus we assume it's licensed)
--
-- Troubleshooting:
-- * If you have licenses for AWR but the script complains, then run 1 awr
--   report manually, then update licensed feature usage using: 
--   EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);
-- * If the AWR interval or retention is incorrect:
--   EXEC DBMS_WORKLOAD_REPOSITORY.modify_snapshot_settings(interval => 60, retention => 10080);

set echo off head off feed off pages 50000 lines 32767 trims on term off verify off

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- command line parameters / default values
column 1 new_value 1 noprint
column 2 new_value 2 noprint
select '' "1", '' "2" from dual where rownum = 0;
define days   = &1 "8"
define offset = &2 "0"
undef 1
undef 2

col dbname  new_val dbname
col zipfile new_val zipfile
col curdate new_val curdate

select name dbname from v$database;
select to_char(sysdate,'YYYYMMDD_HH24MI') curdate from dual;
select name || '_awr_&curdate' || '.zip' zipfile from v$database;

----------------------------------------------------------------
-- Test if AWR is used before - if so, we assume it is licensed
-- Then test for AWR retention >= 1 week  and interval >= 60 min
----------------------------------------------------------------

set term on serveroutput on

-- Test if AWR is used before - if so, we assume it is licensed
-- then get the rest of the info
DECLARE
  awrusage number := 0; -- is AWR report used before
  snap_ret number := 0; -- retention in minutes
  snap_int number := 0; -- interval in minutes
BEGIN
  SELECT extract(day from 24*60*snap_interval) INTO snap_int FROM dba_hist_wr_control where dbid = (select dbid from v$database);
  SELECT extract(day from 24*60*retention)     INTO snap_ret FROM dba_hist_wr_control where dbid = (select dbid from v$database);
  SELECT detected_usages INTO awrusage
  FROM dba_feature_usage_statistics u1
  WHERE u1.version = (SELECT MAX(u2.version) FROM dba_feature_usage_statistics u2 WHERE u2.name = u1.name)
  AND DBID = (SELECT dbid FROM v$database) AND name = 'AWR Report';
  -- Force running even without detected AWR usage: change next line to: IF 1 = 0 THEN
  IF awrusage = 0 THEN
    raise_application_error(-20101, 'Oracle AWR not used before (not licensed?)');
  END IF;
  IF snap_int > 60 THEN
    raise_application_error(-20101, 'AWR interval (' || snap_int || ') too high, must be <= 60');
  END IF;
  IF snap_ret < 10080 THEN
    raise_application_error(-20101, 'AWR retention (' || snap_ret || ') too low, must be >= 10080 (1 week)');
  END IF;
  DBMS_OUTPUT.PUT_LINE('Oracle AWR report extraction tool');
  DBMS_OUTPUT.PUT_LINE('DB Name:   ' || '&dbname');
  DBMS_OUTPUT.PUT_LINE('AWR usage: ' || awrusage || ' times');
  DBMS_OUTPUT.PUT_LINE('Retention: ' || snap_ret || ' minutes');
  DBMS_OUTPUT.PUT_LINE('Interval:  ' || snap_int || ' minutes');
  DBMS_OUTPUT.PUT_LINE('Collect:   ' || &days    || ' days');
  DBMS_OUTPUT.PUT_LINE('Offset:    ' || &offset  || ' days');
  DBMS_OUTPUT.PUT_LINE('ZIP file:  ' || '&zipfile');
END;
/

--------------------------------------------------------
-- create a temporary spool file for report extraction -
--------------------------------------------------------
spool &TMPDIR/collect_awr_tmp.sql
set feedback off term off trims on lines 999 pages 0

alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';
alter session set nls_timestamp_format='YYYY-MM-DD HH24:MI:SS';

select 'host echo Generating AWR reports. Please wait ...' || chr(10)
  || 'set echo off head off feed off trims on lines 999 pages 50000' || chr(10)
  || 'alter session set nls_date_language=american;' header from dual;

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
  , interval '&days'   DAY ndays
  , interval '&offset' DAY offset
  , interval '1'       DAY oneday
  FROM v$database)
SELECT 'set term on escape off' || chr(10) 
  || 'prompt creating awr report for snap id ' || snap_id || ' (' || endtime || ')' || chr(10)
  || 'set term off' || chr(10)
  || 'spool &TMPDIR/' || name || '_awrrpt_' || i || '_' || prev_id  || '_' || snap_id || '.html' || chr(10)
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
ORDER BY snap_id
/
spool off

---------------------------------------------------------------
-- Run temp script and create ZIP file
---------------------------------------------------------------
set term on

@&TMPDIR/collect_awr_tmp.sql
host &REMOVE &TMPDIR&SEP.collect_awr_tmp.sql

prompt creating zip file &&zipfile
host &ZIP -jm &TMPDIR&SEP&&zipfile &TMPDIR/&dbname._*

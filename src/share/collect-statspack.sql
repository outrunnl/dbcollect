-----------------------------------------------------------------------------
-- Title       : collect-statspack.sql
-- Description : collect statspack and other database information
-- Original    : Graham Thornton (oraclejedi@gmail.com)
-- Updates     : Bart Sjerps <bart@outrun.nl>
-- Version     : 1.7
-- License     : GPLv3+
-----------------------------------------------------------------------------
-- Usage: sp_collect [days] [offset]
-- Default (no parameters) collect 8 days of reports
-- days: amount of days to collect
-- offset: shift collect period N days back
--
-- Requires:
-- * Oracle 11g release 1 or higher
-- * zip and unzip in $ORACLE_HOME/bin
-- * Statspack enabled
-- * Some free space in current and /tmp directory
-- * privileges to access the performance views, such as the SYSTEM account
-- * AWR retention > 1 week (10080 minutes), interval max 60 minutes (1 hour)
--
-- This script generates Statspack reports in txt format. 
-- Default is 10 days of snapshots starting 11 days ago,
-- including yesterday. The output is a zip file containing the generated reports.
-- Both temp files and the final zip file are created in the current directory,
-- temp files are cleaned up after successful execution.
-- When using a remote connection, the AWR reports are created on the local
-- system.


set echo off head off feed off pages 50000 lines 32767 trims on term off verify off
set term on
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Settings for Linux/UNIX (uncomment if you run this script directly)
-- define TMPDIR = /tmp
-- define ZIP    = $ORACLE_HOME/bin/zip
-- define REMOVE = /bin/rm
-- define SEP    = /

-- Settings for Windows (uncomment if you run this script directly)
-- define TMPDIR = C:\Temp
-- define ZIP    = zip
-- define REMOVE = del
-- define SEP    = \

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
select name || '_statspack_&curdate' || '.zip' zipfile from v$database;

----------------------------------------------------------------
-- Test if statspack tables exist
----------------------------------------------------------------
prompt here
set term on serveroutput on

DECLARE
  spexists number := 0;
BEGIN
  select count(table_name) into spexists from dba_all_tables where table_name = 'STATS$SNAPSHOT';
  IF spexists = 0 THEN
    raise_application_error(-20101, 'Statspack tables not found');
  END IF;
  DBMS_OUTPUT.PUT_LINE('Oracle Statspack report extraction tool');
  DBMS_OUTPUT.PUT_LINE('DB Name:   ' || '&dbname');
  DBMS_OUTPUT.PUT_LINE('Collect:   ' || &days    || ' days');
  DBMS_OUTPUT.PUT_LINE('Offset:    ' || &offset  || ' days');
  DBMS_OUTPUT.PUT_LINE('ZIP file:  ' || '&zipfile');
END;
/

---------------------------------------------------------------
-- create a temporary spool file for report extraction
---------------------------------------------------------------
spool &TMPDIR/collect_sp_tmp.sql
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
    || 'define report_name=&TMPDIR/' || name    || '_' || i
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

spool off

---------------------------------------------------------------
-- Run temp script and create ZIP file
---------------------------------------------------------------
set term on

@&TMPDIR/collect_sp_tmp.sql
host &REMOVE &TMPDIR&SEP.collect_sp_tmp.sql

prompt creating zip file &&zipfile
host &ZIP -jm &TMPDIR&SEP&&zipfile &TMPDIR/&dbname._*

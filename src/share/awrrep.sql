-----------------------------------------------------------------------------
-- Title       : awrrep.sql
-- Description : creates AWR report (txt format) of the latest snapshot
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-- Disclaimer  : See /usr/share/doc/outrun-sql/COPYING
-----------------------------------------------------------------------------
-- Revision history:
-- 2016-11-10 : Created
-- 2020-06-23 : Added pause for inclusion on dbcollect tools
-----------------------------------------------------------------------------
-- Usage & notes:
-- Just call the script. Only run if you are licensed for Oracle AWR
-----------------------------------------------------------------------------
-- Main logic
-----------------------------------------------------------------------------
SET ECHO OFF HEADING ON UNDERLINE ON;
COLUMN INST_NUM  HEADING "Inst Num"  NEW_VALUE INST_NUM  FORMAT 99999;
COLUMN INST_NAME HEADING "Instance"  NEW_VALUE INST_NAME FORMAT A12;
COLUMN DB_NAME   HEADING "DB Name"   NEW_VALUE DB_NAME   FORMAT A12;
COLUMN DBID      HEADING "DB Id"     NEW_VALUE DBID      FORMAT 9999999999 JUST C;

COLUMN END_SNAP   NEW_VALUE END_SNAP;
COLUMN BEGIN_SNAP NEW_VALUE BEGIN_SNAP;

PAUSE CONTINUE ONLY IF YOU ARE LICENSED FOR AWR. CTRL-C to abort.

SELECT d.dbid dbid
, d.name            db_name
, i.instance_number inst_num
, i.instance_name   inst_name
FROM v$database d, v$instance i
/

select max(SNAP_ID)-1 begin_snap , max(SNAP_ID) end_snap from dba_hist_snapshot
/

DEFINE NUM_DAYS    = 1;
DEFINE REPORT_TYPE = 'text';
DEFINE REPORT_NAME = awr.txt

@?/rdbms/admin/awrrpti

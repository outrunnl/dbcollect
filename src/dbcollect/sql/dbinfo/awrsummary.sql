PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR SNAPSHOT SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID               FORMAT 9999999999
COL INSTANCE_NUMBER    FORMAT 99         HEAD 'Instnum'
COL SNAPSHOTS          FORMAT 999999     HEAD 'Snapshots'
COL SNAPFIRST          FORMAT 9999999    HEAD 'First ID'
COL SNAPSTART          FORMAT A20        HEAD 'Start'
COL SNAP_TIMEZONE      FORMAT A20        HEAD 'Timezone'
COL SNAP_LEVEL         FORMAT 99         HEAD 'Level'
COL SNAP_FLAG          FORMAT 99         HEAD 'Flag'
COL SNAPEND            LIKE SNAPSTART    HEAD 'End'
COL SNAPLAST           LIKE SNAPFIRST    HEAD 'Last ID'
COL ERRORS             FORMAT 99999      HEAD 'Errors'

SELECT DBID
, instance_number
, snap_level
, snap_flag
, COUNT(*)                 snapshots
, MIN(snap_id)             snapfirst
, MAX(snap_id)             snaplast
, MIN(begin_interval_time) snapstart
, MAX(begin_interval_time) snapend
, COUNT(CASE WHEN error_count>0 THEN 1 END) errors
, snap_timezone            tz
FROM dba_hist_snapshot
GROUP BY dbid, instance_number, snap_timezone, snap_level, snap_flag
ORDER BY dbid, snap_flag, instance_number
/

CLEAR COMPUTES COLUMNS

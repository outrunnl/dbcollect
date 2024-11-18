PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR SNAPSHOT LIST
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE COUNT LABEL "Total" OF INSTANCE_NUMBER ON REPORT

COL DBID                FORMAT 9999999999
COL INSTANCE_NUMBER     FORMAT 99                 HEAD 'Instnum'
COL SNAP_ID             FORMAT 999999             HEAD 'Snap ID'
COL SNAP_LEVEL          FORMAT 99                 HEAD 'Level'
COL SNAP_FLAG           FORMAT 99                 HEAD 'Flag'
COL BEGIN_INTERVAL_TIME FORMAT A20                HEAD 'Begin Time'
COL END_INTERVAL_TIME   LIKE BEGIN_INTERVAL_TIME  HEAD 'End Time'
COL STARTUP_TIME        LIKE BEGIN_INTERVAL_TIME  HEAD 'Startup'
COL ELAPSED             FORMAT 9990.99            HEAD 'Elapsed'
COL FLUSH_ELAPSED       LIKE ELAPSED              HEAD 'Flush'
COL ERROR_COUNT         FORMAT 99                 HEAD 'Errors'
 
SELECT dbid
, instance_number
, snap_id
, snap_level
, snap_flag
, begin_interval_time
, end_interval_time
, startup_time
, elapsed
, flush_elapsed
, error_count
FROM (SELECT dbid
  , instance_number
  , snap_id
  , snap_level
  , snap_flag
  , begin_interval_time
  , end_interval_time
  , startup_time
  , error_count
  , EXTRACT(hour   FROM (end_interval_time - begin_interval_time)) * 60 +
    EXTRACT(minute FROM (end_interval_time - begin_interval_time)) elapsed
  , EXTRACT(minute FROM flush_elapsed) * 60 +
    EXTRACT(second FROM flush_elapsed) flush_elapsed
  , ROW_NUMBER() OVER (PARTITION BY INSTANCE_NUMBER ORDER BY SNAP_ID DESC) rn
  FROM  dba_hist_snapshot)
WHERE rn <= 10000
ORDER BY dbid, snap_id, instance_number
/

CLEAR COMPUTE COLUMNS

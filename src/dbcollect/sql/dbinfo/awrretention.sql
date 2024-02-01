PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT AWR RETENTION
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID       FORMAT 9999999999
COL INTERVAL   FORMAT 999999 HEAD 'Interval'
COL RETENTION  LIKE INTERVAL HEAD 'Retention'

SELECT dbid
, extract(day FROM snap_interval)*24*60 + extract(hour FROM snap_interval)*60 + extract(minute FROM snap_interval) interval
, extract(day FROM retention)*24*60     + extract(hour FROM retention)*60     + extract(minute FROM retention)     retention
FROM dba_hist_wr_control
/

CLEAR COMPUTES COLUMNS

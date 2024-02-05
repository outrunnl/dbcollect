PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BACKUP JOBS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL SIZE_MB     FORMAT 99,999,999,990.99
COL SESSION_KEY FORMAT 99999   HEAD 'Key'
COL INPUT_TYPE  FORMAT A16     HEAD 'Type'
COL DEVTYPE     FORMAT A10     HEAD 'Device'
COL STATUS      FORMAT A25     HEAD 'Status'
COL TS          FORMAT A19     HEAD 'Start'
COL ELAPSED     FORMAT 99990   HEAD 'Elapsed'
COL INPUT_MB    LIKE SIZE_MB   HEAD 'Read'
COL OUTPUT_MB   LIKE SIZE_MB   HEAD 'Written'
COL RATIO       FORMAT 90.9999 HEAD 'Ratio'

SELECT SESSION_KEY
, input_type
, output_device_type     devtype
, status
, to_char(start_time)    ts
, elapsed_seconds        elapsed
, input_bytes  / 1048576 input_mb
, output_bytes / 1048576 output_mb
, compression_ratio      ratio
FROM V$RMAN_BACKUP_JOB_DETAILS
ORDER BY start_time
/

CLEAR COMPUTES COLUMNS

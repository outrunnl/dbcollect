PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BACKUP JOBS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL SIZE_MB     FORMAT 99,999,999,990.99
COL SESSION_KEY FORMAT 99999   HEAD 'Key'
COL INPUT_TYPE  FORMAT A12     HEAD 'Type'
COL DEVTYPE     FORMAT A10     HEAD 'Device'
COL STATUS      FORMAT A25     HEAD 'Status'
COL TS          FORMAT A19     HEAD 'Start'
COL ELAPSED     FORMAT 99990   HEAD 'Elapsed'
COL INPUT_MB    LIKE SIZE_MB   HEAD 'Read'
COL OUTPUT_MB   LIKE SIZE_MB   HEAD 'Written'
COL RATIO       FORMAT 90.9999 HEAD 'Ratio'

SELECT SESSION_KEY
, INPUT_TYPE
, OUTPUT_DEVICE_TYPE     DEVTYPE
, STATUS
, TO_CHAR(start_time)    TS
, ELAPSED_SECONDS        ELAPSED
, INPUT_BYTES  / 1048576 INPUT_MB
, OUTPUT_BYTES / 1048576 OUTPUT_MB
, COMPRESSION_RATIO      RATIO
FROM V$RMAN_BACKUP_JOB_DETAILS
ORDER BY start_time
/

CLEAR COMPUTES COLUMNS

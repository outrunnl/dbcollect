PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT OS STATS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL STAT_NAME FORMAT A24            HEAD 'Name'
COL VALUE     FORMAT 99999999999999 HEAD 'Value'
COL COMMENTS  FORMAT A80            HEAD 'Comments'

SELECT   stat_name, value, comments
FROM     v$osstat
WHERE    stat_name IN ('NUM_CPUS', 'NUM_CPU_CORES', 'NUM_CPU_SOCKETS', 'PHYSICAL_MEMORY_BYTES', 'FREE_MEMORY_BYTES', 'IDLE_TIME', 'BUSY_TIME', 'USER_TIME', 'SYS_TIME', 'IOWAIT_TIME')
ORDER BY osstat_id
/

CLEAR COLUMNS

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT RAC INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL INSTANCE_NAME    FORMAT A14  HEAD 'Instance Name'
COL INSTANCE_NUMBER  FORMAT 99   HEAD 'Instance Number'
COL HOST_NAME        FORMAT A25  HEAD 'Hostname'
COL STATUS           FORMAT A10  HEAD 'Status'
COL STARTUP_TIME                 HEAD 'Startup Time'
COL THREAD#          FORMAT  99  HEAD 'Thread'
COL LOGINS           FORMAT A10  HEAD 'Logins'

SELECT instance_name
, instance_number
, host_name
, status
, startup_time
, thread#
, logins
FROM gv$instance
ORDER BY instance_number
/

CLEAR COLUMNS

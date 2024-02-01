PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INSTANCE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL INSTANCE_NUMBER  FORMAT 99   HEAD 'Instance Number'
COL INSTANCE_NAME    FORMAT A14  HEAD 'Instance Name'
COL HOST_NAME        FORMAT A25  HEAD 'Hostname'
COL VERSION          FORMAT A16  HEAD 'Version'
COL STARTUP_TIME                 HEAD 'Startup Time'
COL STATUS           FORMAT A10  HEAD 'Status'
COL PARALLEL         FORMAT A8   HEAD 'Parallel'
COL LOGINS           FORMAT A10  HEAD 'Logins'
COL DATABASE_STATUS  FORMAT A16  HEAD 'DB Status'
COL INSTANCE_ROLE    FORMAT A18  HEAD 'Instance Role'
COL BLOCKED          FORMAT A8   HEAD 'Blocked'

SELECT instance_number
, instance_name
, host_name
, version
, startup_time
, status
, parallel
, logins
, database_status
, instance_role
, blocked
FROM v$instance
/


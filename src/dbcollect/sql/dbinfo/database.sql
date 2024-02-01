PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID                   FORMAT 9999999999
COL DBNAME                 FORMAT A10        HEAD 'DB Name'
COL CREATED                                  HEAD 'Created'
COL RESETLOGS_TIME                           HEAD 'Resetlogs Time'
COL LOG_MODE               FORMAT A12        HEAD 'Log Mode'
COL CONTROLFILE_TYPE       FORMAT A16        HEAD 'Controlfile Type'
COL CONTROLFILE_CREATED                      HEAD 'Controlfile Created'
COL OPEN_MODE              FORMAT A20        HEAD 'Open Mode'
COL PROTECTION_MODE        FORMAT A20        HEAD 'Protection Mode'
COL DATABASE_ROLE          FORMAT A16        HEAD 'Database Role'
COL ARCHIVELOG_COMPRESSION FORMAT A22        HEAD 'Archivelog Compression'
COL SWITCHOVER_STATUS      FORMAT A20        HEAD 'Switchover Status'
COL DATAGUARD_BROKER       FORMAT A16        HEAD 'Dataguard Broker'
COL FORCE_LOGGING          FORMAT A18        HEAD 'Force Logging'
COL PLATFORM_NAME          FORMAT A20        HEAD 'Platform Name'
COL FLASHBACK_ON           FORMAT A18        HEAD 'Flashback On'
COL DB_UNIQUE_NAME         FORMAT A20        HEAD 'DB Unique Name'
COL FS_FAILOVER_STATUS     FORMAT A18        HEAD 'FS Failover Status'
COL PRIMARY_DB_UNIQUE_NAME FORMAT A22        HEAD 'Primary DB Unique Name'

SELECT dbid
, name dbname
, created
, resetlogs_time
, log_mode
, controlfile_type
, controlfile_created
, open_mode
, protection_mode
, database_role
, archivelog_compression
, switchover_status
, dataguard_broker
, force_logging
, platform_name
, flashback_on
, db_unique_name
, fs_failover_status
, primary_db_unique_name
FROM v$database
/
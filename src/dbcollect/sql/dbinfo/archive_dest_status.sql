PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ARCHIVE DESTINATION STATUS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DEST_ID         FORMAT 99  HEAD 'Dest ID'
COL DEST_NAME       FORMAT A20 HEAD 'Destination'
COL STATUS          FORMAT A10 HEAD 'Status'
COL TYPE            FORMAT A14 HEAD 'Type'
COL DATABASE_MODE   FORMAT A16 HEAD 'Database Mode'
COL RECOVERY_MODE   FORMAT A24 HEAD 'Recovery Mode'
COL PROTECTION_MODE FORMAT A22 HEAD 'Protection Mode'
COL DESTINATION     FORMAT A20 HEAD 'Destination'
COL DB_UNIQUE_NAME  FORMAT A20 HEAD 'DB Unique Name'
COL ERROR           FORMAT A60 HEAD 'Error'

SELECT dest_id
, dest_name
, status
, TYPE
, database_mode
, recovery_mode
, protection_mode
, destination
, db_unique_name
-- , synchronization_status
-- , gap_status
, error
FROM v$archive_dest_status
WHERE STATUS != 'INACTIVE'
/

CLEAR COLUMNS

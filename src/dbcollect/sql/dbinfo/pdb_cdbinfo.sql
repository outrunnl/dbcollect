PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CONTAINER INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID                   FORMAT 9999999999
COL DBNAME                 FORMAT A10        HEAD 'DB Name'
COL CDB                    FORMAT A4         HEAD 'CDB'
COL CREATED                                  HEAD 'Created'
COL DB_UNIQUE_NAME         FORMAT A20        HEAD 'DB Unique Name'

SELECT dbid
, name dbname
, cdb
, created
, db_unique_name
FROM v$database
/

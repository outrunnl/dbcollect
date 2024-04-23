PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT WATERMARK STATISTICS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DBID         FORMAT 9999999999
COL NAME         FORMAT A30                        HEAD 'Name'
COL VERSION      FORMAT A16                        HEAD 'Version'
COL HIGHWATER    FORMAT 999,999,999,999,999,990.00 HEAD 'Highwater'
COL LAST_VALUE   LIKE HIGHWATER                    HEAD 'Last Value'
COL DESCRIPTION  FORMAT A80                        HEAD 'Description'

SELECT   dbid, name, version, highwater, last_value, description
FROM     dba_high_water_mark_statistics
ORDER BY name
/

CLEAR COLUMNS

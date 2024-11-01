PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATAGUARD CONFIG
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- not on 11g

COL DB_UNIQUE_NAME FORMAT A20                HEAD 'DB Unique Name'
COL PARENT_DBUN    LIKE DB_UNIQUE_NAME       HEAD 'Parent DB'
COL DEST_ROLE      FORMAT A20                HEAD 'Destination Role'
COL CURRENT_SCN    FORMAT 999999999999999999 HEAD 'Current SCN'

SELECT DB_UNIQUE_NAME
, PARENT_DBUN
, DEST_ROLE
, CURRENT_SCN
FROM v$dataguard_config
/

CLEAR COLUMNS
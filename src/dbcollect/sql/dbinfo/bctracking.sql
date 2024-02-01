PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BLOCK CHANGE TRACKING
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL STATUS      FORMAT A10               HEAD 'Status'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A160              HEAD 'Filename'

SELECT status
, bytes/1048576 SIZE_MB
, filename
FROM V$BLOCK_CHANGE_TRACKING
/

CLEAR COLUMNS


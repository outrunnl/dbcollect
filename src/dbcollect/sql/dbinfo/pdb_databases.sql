PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT PDB DATABASES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL PDB_NAME   FORMAT A20               HEAD 'PDB'
COL DBID       FORMAT 9999999999        HEAD 'DBID'
COL GUID       FORMAT A32
COL OPEN_MODE  FORMAT A10               HEAD 'Open Mode'
COL RESTRICTED FORMAT A10               HEAD 'Restricted'
COL OPEN_TIME                           HEAD 'Open Time'
COL SIZE_MB    FORMAT 99,999,999,990.99 HEAD 'Size'
COL BLKSZ      FORMAT 99                HEAD 'Blocksize'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

SELECT name pdb_name
, dbid
, guid
, open_mode
, restricted
, CAST(open_time AS date) open_time
, total_size/1047576 size_mb
, block_size/1024 blksz
FROM v$pdbs
ORDER BY name
/

CLEAR COMPUTES COLUMNS

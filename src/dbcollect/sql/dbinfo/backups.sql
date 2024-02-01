PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT BACKUPS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB FILES ON REPORT

COL FILE_TYPE    FORMAT A15               HEAD 'File type'
COL OBSOLETE     FORMAT A8                HEAD 'Obsolete'
COL BACKUP_TYPE  FORMAT A12               HEAD 'Backup type'
COL BS_INCR_TYPE FORMAT A12               HEAD 'Level'
COL COMPRESSED   FORMAT A10               HEAD 'Compressed'
COL STATUS       FORMAT A12               HEAD 'Status'
COL SIZE_MB      FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILES        FORMAT 999990            HEAD 'Files'

SELECT file_type
, obsolete
, backup_type
, bs_incr_type
, compressed
, STATUS
, SUM(BYTES)/1048576 size_mb
, COUNT(*)           files
FROM v$backup_files
WHERE file_type NOT IN ('DATAFILE')
GROUP BY file_type, backup_type, bs_incr_type, compressed, obsolete, status
ORDER BY obsolete DESC, file_type
/

CLEAR COMPUTES COLUMNS

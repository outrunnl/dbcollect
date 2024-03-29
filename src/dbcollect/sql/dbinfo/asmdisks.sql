PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISKS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DISKNAME   FORMAT A30               HEAD 'Disk name'
COL DG_NAME    FORMAT A30               HEAD 'Diskgroup'
COL PATH       FORMAT A120              HEAD 'Path'
COL USED_MB    FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB    LIKE USED_MB             HEAD 'Free'
COL ALLOCATED  LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED   FORMAT 990.99            HEAD 'Used %'
COL CREATED                             HEAD 'Created'
COL MOUNTED                             HEAD 'Mounted'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT d.name                      diskname
, COALESCE(dg.name, header_status) dg_name
, (d.total_mb - d.free_mb)         used_mb
, d.free_mb                        free_mb
, d.os_mb                          allocated
, 100*(d.total_mb - d.free_mb) /
    NULLIF(d.total_mb,0)           pct_used
, create_date                      created
, mount_date                       mounted
, path
FROM gv$asm_disk d
LEFT OUTER JOIN v$asm_diskgroup dg USING (group_number)
JOIN v$instance ON inst_id=instance_number
WHERE group_number <> 0
ORDER BY d.name, path
/

CLEAR COMPUTES COLUMNS
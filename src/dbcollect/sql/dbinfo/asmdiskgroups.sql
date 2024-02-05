PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM DISK GROUPS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL DG_NAME   FORMAT A25               HEAD 'Diskgroup'
COL AU_SIZE   FORMAT 99                HEAD 'AU'
COL MIRRORS   FORMAT 9                 HEAD 'Mir'
COL STATE     FORMAT A10               HEAD 'State'
COL TYPE      FORMAT A6                HEAD 'Type'
COL USED_MB   FORMAT 99,999,999,990.99 HEAD 'Used'
COL FREE_MB   LIKE USED_MB             HEAD 'Free'
COL ALLOCATED LIKE USED_MB             HEAD 'Allocated'
COL PCT_USED  FORMAT 990.99            HEAD 'Used %'
COL CREATED                            HEAD 'Created'
COL MOUNTED                            HEAD 'Mounted'

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF USED_MB FREE_MB ALLOCATED ON REPORT

SELECT name dg_name
, allocation_unit_size/1048576 au_size
, state
, type
, DECODE(type, 'EXTERN',1,'NORMAL',2,'HIGH',3,0) mirrors
, (total_mb - free_mb) used_mb
, free_mb              free_mb
, total_mb             allocated
, ROUND((1- (free_mb / NULLIF(total_mb,0)))*100, 2) PCT_USED
, created
, mounted 
FROM v$asm_diskgroup
JOIN (
    SELECT group_number
    , min(create_date) created
    , min(mount_date)  mounted
    FROM v$asm_disk
    GROUP BY group_number
) USING (group_number)
ORDER BY name
/

CLEAR COMPUTES COLUMNS
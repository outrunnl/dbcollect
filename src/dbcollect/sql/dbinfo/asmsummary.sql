PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT ASM SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB SPACE_MB FILES ON REPORT

COL FILETYPE      FORMAT A20               HEAD 'Filetype'
COL DG_NAME       FORMAT A25               HEAD 'Diskgroup'
COL SIZE_MB       FORMAT 99,999,999,990.99 HEAD 'Size'
COL ALLOCATED_MB  LIKE SIZE_MB             HEAD 'Allocated'
COL FILES         FORMAT 999990            HEAD 'Files'

SELECT f.type filetype
, name dg_name
, SUM(f.bytes)/1048576 size_mb
, SUM(f.space)/1048576 allocated_mb
, COUNT(*) files
FROM v$asm_file f
JOIN v$asm_diskgroup d USING (group_number)
GROUP BY f.type, name
ORDER BY 1, 2
/

CLEAR COMPUTES COLUMNS
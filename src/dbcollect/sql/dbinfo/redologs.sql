PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT REDO LOGS
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL GROUP#    FORMAT 99            HEAD 'Group'
COL TYPE      FORMAT A12           Head 'Type'
COL THREAD#   FORMAT 9             HEAD 'Thread'
COL SEQUENCE# FORMAT 99999999      HEAD 'Sequence'
COL ARCHIVED  FORMAT A8            HEAD 'Archived'
COL BLKSZ     FORMAT 90.9          HEAD 'BS(K)'
COL SIZE_MB   FORMAT 99,999,990.99 HEAD 'Size'
COL MEMBER    FORMAT A50           HEAD 'Filename'


SELECT group#, TYPE, thread#, sequence#, archived, blocksize/1024 blksz, bytes/1048576 size_mb, member
FROM   v$log JOIN v$logfile USING (group#)
UNION ALL
SELECT group#, TYPE, thread#, sequence#, archived, blocksize/1024 blksz, bytes/1048576 size_mb, member
FROM   v$standby_log a JOIN v$logfile b USING (group#)
ORDER BY group#, thread#
/

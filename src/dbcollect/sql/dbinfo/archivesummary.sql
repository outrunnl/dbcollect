PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DAILY ARCHIVELOG SUMMARY
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF FILES SIZE_MB ON REPORT

COL DS        FORMAT A12               HEADING 'Date'
COL WEEKDAY   FORMAT A4                HEADING 'Day'
COL FILES     FORMAT 999990            HEADING 'Logs'
COL SIZE_MB   FORMAT 99,999,999,990.99 HEAD    'Size'
COL AVG7      LIKE SIZE_MB             HEADING 'Week avg'

SELECT to_char(datestamp,'YYYY-MM-DD') ds
, to_char(datestamp,'Dy') weekday
, files
, size_mb
, AVG(size_mb) OVER (ORDER BY rn DESC rows BETWEEN 6 preceding AND current row) avg7
FROM (SELECT datestamp
  , COUNT(*) files
  , SUM(bytes/1048576) SIZE_MB
  , ROW_NUMBER() OVER (ORDER BY datestamp DESC) rn
  FROM (SELECT TRUNC(completion_time) datestamp, (blocks * block_size) BYTES FROM v$archived_log)
  GROUP BY datestamp
)
WHERE rn BETWEEN 2 AND 100
ORDER BY datestamp
/

CLEAR COMPUTES COLUMNS

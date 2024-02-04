PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE FEATURE USAGE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL NAME                   FORMAT A55   HEAD 'Feature'
COL DBID                   FORMAT 9999999999
COL VERSION                FORMAT A14   HEAD 'Version'
COL DETECTED_USAGES        FORMAT 9999  HEAD 'Count'
COL CURRENTLY_USED         FORMAT A10   HEAD 'In Use'
COL FIRST_USAGE_DATE                    HEAD 'First Usage'
COL LAST_USAGE_DATE                     HEAD 'Last Usage'
COL LAST_SAMPLE_DATE                    HEAD 'Last Sample'
COL AGE                    FORMAT 99999 HEAD 'Age'
COL DESCRIPTION            FORMAT A160  HEAD 'Description'

SELECT name
, dbid
, version
, detected_usages
, currently_used
, first_usage_date
, last_usage_date
, last_sample_date
, round(last_sample_date - last_usage_date) age
, description
FROM  dba_feature_usage_statistics
WHERE DETECTED_USAGES > 0
ORDER BY dbid, name, version
/

CLEAR COMPUTES COLUMNS

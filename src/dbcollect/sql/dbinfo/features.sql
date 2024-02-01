PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE FEATURE USAGE
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Thanks to Oracle-base, see https://oracle-base.com/articles/misc/tracking-database-feature-usage

COL FEATURE FORMAT A55   HEAD 'Feature'
COL USAGES  FORMAT 9,999 HEAD 'Usage'
COL INUSE   FORMAT A10   HEAD 'In Use'
COL VERSION FORMAT A14   HEAD 'Version'

SELECT u1.name feature, u1.detected_usages usages, u1.currently_used inuse, u1.version version
-- , u1.first_usage_date, u1.last_usage_date, u1.description
FROM   dba_feature_usage_statistics u1
WHERE  u1.version = (SELECT MAX(u2.version)
                     FROM   dba_feature_usage_statistics u2
                     WHERE  u2.name = u1.name)
AND    u1.detected_usages > 0
AND    u1.dbid = (SELECT dbid FROM v$database)
ORDER BY name
/

CLEAR COMPUTES COLUMNS

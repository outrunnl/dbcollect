-----------------------------------------------------------------------------
-- Title       : awrusage.sql
-- Description : Report number of usages of 'AWR report' for current DBID
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-----------------------------------------------------------------------------
SELECT detected_usages FROM dba_feature_usage_statistics u1
WHERE u1.version = (SELECT MAX(u2.version) FROM dba_feature_usage_statistics u2 WHERE u2.name = u1.name)
AND DBID = (SELECT dbid FROM v$database) AND name = 'AWR Report'
/

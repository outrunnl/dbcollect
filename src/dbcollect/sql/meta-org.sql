-----------------------------------------------------------------------------
-- Title       : meta.sql
-- Description : Get Oracle instance and database metadata
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on

ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
WHENEVER SQLERROR EXIT 0

COL parallel               FORMAT A8
COL blocked                FORMAT A8
COL dataguard_broker       FORMAT A16
COL archivelog_compression FORMAT A24

SELECT instance_number
, instance_name
, host_name
, version
, startup_time
, status
, parallel
, sysdate
, regexp_substr(version, '\d+') version_major
FROM v$instance
/

SELECT dbid
, name dbname
, db_unique_name
, database_role
, created
FROM v$database
/

SELECT 
  (SELECT COUNT(table_name) statspack FROM all_tables WHERE table_name = 'STATS$SNAPSHOT') AS STATSPACK
, (SELECT SUM(detected_usages) FROM dba_feature_usage_statistics u1
	WHERE u1.version = (SELECT MAX(u2.version) FROM dba_feature_usage_statistics u2 WHERE u2.name = u1.name)
	AND DBID = (SELECT dbid FROM v$database) AND name = 'AWR Report') AS AWRUSAGE
FROM dual
/
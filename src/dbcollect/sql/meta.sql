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

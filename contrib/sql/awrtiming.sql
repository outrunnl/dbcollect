-----------------------------------------------------------------------------
-- Title       : awrtiming.sql
-- Description : Measure time it takes to generate one AWR report
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------

SET SERVEROUTPUT ON
SET TIMING ON

DECLARE
        dbid     INTEGER;
        instnum  INTEGER;
        lastsnap INTEGER;
        awrlines INTEGER;
BEGIN
        SELECT dbid INTO dbid FROM v$database;
        SELECT instance_number INTO instnum FROM v$instance;
        SELECT MAX(snap_id) INTO lastsnap FROM DBA_HIST_SNAPSHOT;
        SELECT COUNT(output) INTO awrlines FROM table (dbms_workload_repository.awr_report_html(dbid,instnum,lastsnap-1,lastsnap));

        dbms_output.put_line('AWR Report for DBID ' || dbid 
                || ', INSTANCE ' || instnum 
                || ', snapid ' || TO_CHAR(lastsnap-1) || '-' || TO_CHAR(lastsnap)
                || ' has ' || awrlines || ' lines.');

END;
/

-----------------------------------------------------------------------------
-- Title       : awr_report.sql
-- Description : Generate an AWR report and move it after completion
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Notes       : Not to be called directly but from Python so vars are expanded
-----------------------------------------------------------------------------
SPOOL {filename}
SELECT output FROM table (dbms_workload_repository.awr_report_html({dbid},{inst},{beginsnap},{endsnap}));
SPOOL OFF
HOST mv {filename} awr/{filename}

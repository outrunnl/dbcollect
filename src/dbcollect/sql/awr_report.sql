-----------------------------------------------------------------------------
-- Title       : awr-report.sql
-- Description : Template for generating AWR reports in html
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Notes       : Not to be called directly but from Python so vars are expanded
-----------------------------------------------------------------------------
spool {sid}_awrrpt_{inst}_{beginsnap}_{endsnap}_{timestamp}.html
select output from table (dbms_workload_repository.awr_report_html({dbid},{inst},{beginsnap},{endsnap}));
spool off

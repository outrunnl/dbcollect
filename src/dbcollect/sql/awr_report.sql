
spool {sid}_awrrpt_{inst}_{beginsnap}_{endsnap}_{timestamp}.html
select output from table (dbms_workload_repository.awr_report_html({dbid},{inst},{beginsnap},{endsnap}));
spool off

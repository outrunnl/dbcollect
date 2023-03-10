SPOOL {filename}
SELECT output FROM table (dbms_workload_repository.awr_report_html({dbid},{inst},{beginsnap},{endsnap}));
SPOOL OFF
HOST mv {filename} awr/{filename}

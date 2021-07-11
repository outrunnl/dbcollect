-----------------------------------------------------------------------------
-- Title       : sp-report.sql
-- Description : Template for generating Statspack reports
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-- Notes       : Not to be called directly but from Python so vars are expanded
-----------------------------------------------------------------------------
set term off escape off
define begin_snap={beginsnap}
define end_snap={endsnap}
define report_name={sid}_{inst}_statspack_{beginsnap}_{endsnap}_{timestamp}.txt
@?/rdbms/admin/spreport

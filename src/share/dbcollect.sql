-----------------------------------------------------------------------------
-- Title       : dbcollect.sql
-- Description : Run collect-awr and dbinfo with correct environment (linux)
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-----------------------------------------------------------------------------

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Change to 'statspack' for STATSPACK instead of AWR
define STATS  = awr

-- Unix/Linux settings (comment out with -- for Windows)
define TMPDIR = /tmp
define ZIP    = $ORACLE_HOME/bin/zip
define REMOVE = /bin/rm
define SEP    = /

-- Windows settings (uncomment for Windows)
-- define TMPDIR = C:\Temp
-- define ZIP    = zip
-- define REMOVE = del
-- define SEP    = \

-- Do not change below this

set feed off
column 1 new_value 1 noprint
column 2 new_value 2 noprint
select '' "1", '' "2" from dual where rownum = 0;

set term off
col dbname  new_val dbname
select name dbname from v$database;

spool &TMPDIR/&dbname._info.txt
@dbinfo
spool off
set term on
@@collect-&stats &1 &2

undef 1
undef 2

exit;

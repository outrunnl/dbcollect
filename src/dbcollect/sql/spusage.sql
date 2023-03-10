-----------------------------------------------------------------------------
-- Title       : spusage.sql
-- Description : Report Statspack usage
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------
SELECT COUNT(table_name) FROM all_tables WHERE table_name = 'STATS$SNAPSHOT'
/

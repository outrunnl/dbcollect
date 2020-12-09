-- ----------------------------------------------------------------------------
-- Title       : instance.sql
-- Description : collect only instance information
-- Author      : Bart Sjerps <bart@outrun.nl>
-- License     : GPLv3+
-- ----------------------------------------------------------------------------
-- This script collects instance info about the current connected database
-- It is a subset of dbinfo.sql - only to be used when instance is in 'STARTED'
-- state
-- ----------------------------------------------------------------------------

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DBINFO version 1.2.2
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INSTANCE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COL METRIC      FORMAT A20        HEAD 'Metric'
COL VALUE       FORMAT A80        HEAD 'Value'

SELECT 'report date' metric,       to_char(sysdate) value   FROM dual
UNION ALL SELECT 'hostname',       host_name                FROM v$instance
UNION ALL SELECT 'instance',       instance_name            FROM v$instance
UNION ALL SELECT 'version',        version                  FROM v$instance
UNION ALL SELECT 'inst_number',    to_char(instance_number) FROM v$instance
UNION ALL SELECT 'startup',        to_char(startup_time)    FROM v$instance
UNION ALL SELECT 'rac',            parallel                 FROM v$instance
UNION ALL SELECT 'inst_role',      instance_role            FROM v$instance
UNION ALL SELECT 'status',         status                   FROM v$instance
UNION ALL SELECT 'db_status',      database_status          FROM v$instance
UNION ALL SELECT 'logins',         logins                   FROM v$instance
UNION ALL SELECT 'blocked',        blocked                  FROM v$instance
UNION ALL SELECT 'uptime (days)',  to_char(round(sysdate - startup_time,2)) FROM v$instance
UNION ALL SELECT lower(replace(stat_name,'NUM_','')), to_char(value)
          FROM   v$osstat
          WHERE  stat_name IN ('NUM_CPUS','NUM_CPU_CORES','NUM_CPU_SOCKETS')
UNION ALL SELECT 'memory', to_char(round(value/1048576))
          FROM   v$osstat
          WHERE  stat_name = 'PHYSICAL_MEMORY_BYTES'
UNION ALL SELECT 'product', substr(banner, 1, instr(banner,'Release')-2)
          FROM   v$version
          WHERE  banner LIKE 'Oracle Database%'
/

-----------------------------------------------------------------------------
-- Title       : database.sql
-- Description : collect only instance information
-- Author      : Bart Sjerps <bart@dirty-cache.com>
-- License     : GPLv3+
-----------------------------------------------------------------------------
-- This script collects instance and database info about the current connected
-- database. It is a subset of dbinfo.sql - only to be used when instance is
-- in 'MOUNTED' state

SET colsep '|'
SET tab off feedback off verify off heading on lines 1000 pages 50000 trims on
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';


COL METRIC      FORMAT A20        HEAD 'Metric'
COL VALUE       FORMAT A80        HEAD 'Value'

PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DBINFO version 1.4.0
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT INSTANCE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SELECT 'report date' metric,       to_char(sysdate) value   FROM dual
UNION ALL SELECT 'hostname',       host_name                FROM v$instance
UNION ALL SELECT 'instance',       instance_name            FROM v$instance
UNION ALL SELECT 'version',        version                  FROM v$instance
UNION ALL SELECT 'inst_number',    to_char(instance_number) FROM v$instance
UNION ALL SELECT 'startup',        to_char(startup_time)    FROM v$instance
UNION ALL SELECT 'rac',            parallel                 FROM v$instance
UNION ALL SELECT 'inst_role',      instance_role            FROM v$instance -- 11+ only
UNION ALL SELECT 'status',         status                   FROM v$instance
UNION ALL SELECT 'db_status',      database_status          FROM v$instance
UNION ALL SELECT 'logins',         logins                   FROM v$instance
UNION ALL SELECT 'blocked',        blocked                  FROM v$instance -- 11+ only
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

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT DATABASE INFO
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SELECT 'dbname' metric,              name value                   FROM v$database
UNION ALL SELECT 'platform',         platform_name                FROM v$database
UNION ALL SELECT 'dbid',             to_char(dbid)                FROM v$database
UNION ALL SELECT 'unique_name',      db_unique_name               FROM v$database
UNION ALL SELECT 'open_mode',        open_mode                    FROM v$database
UNION ALL SELECT 'log_mode',         log_mode                     FROM v$database
UNION ALL SELECT 'force_logging',    force_logging                FROM v$database
UNION ALL SELECT 'prot_mode',        protection_mode              FROM v$database
UNION ALL SELECT 'prot_level',       protection_level             FROM v$database
UNION ALL SELECT 'db_role',          database_role                FROM v$database
UNION ALL SELECT 'flashback',        flashback_on                 FROM v$database
UNION ALL SELECT 'created',          to_char(created)             FROM v$database
UNION ALL SELECT 'ctrlfile_type',    controlfile_type             FROM v$database
UNION ALL SELECT 'ctrlfile_created', to_char(controlfile_created) FROM v$database
UNION ALL SELECT 'switchover',       switchover_status            FROM v$database
UNION ALL SELECT 'dgbroker',         dataguard_broker             FROM v$database
UNION ALL SELECT 'arch_compress',    archivelog_compression       FROM v$database
-- UNION ALL SELECT 'primary_u_name',   primary_db_unique_name       FROM v$database
/

PROMPT
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT CORE DATABASE FILES
PROMPT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BREAK ON REPORT
COMPUTE SUM LABEL "Total" OF SIZE_MB ON REPORT

COL FILETYPE    FORMAT A20               HEAD 'Filetype'
COL BLOCKSIZE   FORMAT 90.9              HEAD 'BS(K)'
COL SIZE_MB     FORMAT 99,999,999,990.99 HEAD 'Size'
COL FILENAME    FORMAT A200              HEAD 'Filename'

SELECT TYPE       FILETYPE
, BLOCK_SIZE/1024 BLOCKSIZE
, BYTES/1048576   SIZE_MB
, NAME          FILENAME
FROM (
  SELECT           'DATAFILE' type, bytes, block_size, name   FROM v$datafile
  UNION ALL SELECT 'TEMPFILE',      bytes, block_size, name   FROM v$tempfile
  UNION ALL SELECT 'CONTROLFILE',   block_size*file_size_blks bytes, block_size, name FROM v$controlfile
  UNION ALL SELECT 'REDOLOG',       bytes, blocksize,  member fROM v$log a JOIN v$logfile b ON a.Group#=b.Group#
)
ORDER BY 1, 2
/

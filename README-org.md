DBCollect - Oracle Database Info Collector
=

## Description

DBCollect is a metadata collection tool for Oracle databases.

The main part is a Python tool that collects various system files and
the output of some commands, as well as AWR or Statspack reports for each
database instance, and other database information.

The results are collected in a ZIP file named
/tmp/dbcollect-`<`hostname>.zip

## Install

### Linux

The easiest on RHEL-compatible systems is to install the RPM package.
First, install the Outrun Extras repository:

`yum install http://yum.outrun.nl/outrun-extras.rpm`

Then install dbcollect:

`yum install dbcollect`

If you don't want to install the RPM, follow the UNIX / Manual install procedure below.

### Unix / Manual install

Make sure Python is available (dbcollect uses Python 2 but will switch to Python 3 in the future).
Python (2) is installed by default on Linux systems. On Solaris it is usually also available.
On AIX you need to install it separately.

Download and unpack the ZIP archive from:

[latest version](https://github.com/outrunnl/dbcollect/releases/latest)

Make sure the directory is readable by all users.

## Info collected by dbcollect:

- AWR or Statspack reports for a default period of about 10 days
- Database configuration (such as version, dbname, database and system settings)
- Database size
- Core database file info (datafiles, tempfiles, redo logs, control files)
- Additional database file info (backup, archive logs, flashback logs)
- Tablespace details
- Segment sizes
- ASM disk group info
- Init parameters
- Feature usage
- Linux: CPU, memory, disks, network interfaces etc, SAR data
- AIX / Solaris: basic system info (more TBD). SAR TBD.
- Windows: Not yet supported (TBD)

More collectors may be added in the future.

## Usage

### Important note

DBCollect by default attempts to collect Oracle AWR reports in HTML format. For this, Oracle requires Diagnostics Pack (see Oracle doc id 1490798.1).
DBCollect can not directly determine if you have this license or not. As an indirect method, it checks the dba_feature_usage_statistics table whether "AWR Reports" has been used previously or not. If this is NOT the case, dbcollect produces an error message ORA-20101 "Oracle AWR not used before (not licensed?)" and aborts.

It is possible that you are licensed correctly but never used AWR reports on this specific database - in that case, DBCollect thinks you are not licensed and gives up.
If you are NOT licensed for diagnostics pack then you can use Statspack instead (see section below)
If you ARE licensed, you can run dbcollect with the --force option. DBcollect will ignore the AWR detection and just generate the reports.

More info on Oracle feature usage: [Oracle Feature Usage](https://oracle-base.com/articles/misc/tracking-database-feature-usage)

### Basic operation

If installed from the RPM package:
Just run 

`dbcollect`

as 'oracle' user or root (assuming the database runs under user 'oracle')

If installed from ZIP file:

- Make sure the directory in which you unzip is readable for all users.
- Go to the top directory and run
`./dbcollect`

When complete, a ZIP file will be created in the /tmp directory. This file contains the database overview and, by default, the last 7 days of AWR or Statspack reports. All temp files will be either cleaned up or moved into the ZIP archive.


### Oracle running as other user than 'oracle'

DBCollect by default switches to user 'oracle' if you run it as root. If you do NOT run as root, run it as the user that Oracle database runs as.
If you run as root and the database user is NOT 'oracle', use the -u/--user option:

`dbcollect --user dbuser`

### Statspack

By default, dbcollect attempts to run AWR reports but has a built-in protection against license violations if no previous AWR usage can be detected. If you don't have Diagnostics/Tuning package, you can run Statspack reports instead, provided statspack is running and collecting metrics.

The collection period can be changed with parameters as long as reports are available. Run dbcollect with the --statspack option:

`dbcollect --statspack`

Statspack is not configured by default on Oracle but requires initial setup.

To setup Statspack, see [Oracle-base: Statspack](https://oracle-base.com/articles/8i/statspack-8i)

After setup, you need to wait 7 days to let it collect performance information before running dbcollect.

### Changing collect period

By default, dbcollect collects the last 10 days of AWR/Statspack data. To change, use the --days option:

`dbcollect --days 14`

### Non-Linux (UNIX) systems

DBCollect now partly supports AIX and Solaris systems. You need to have Python 2 installed.

Just run 'dbcollect' - it will fail on the 'syscollect' part that retrieves Linux information but will still
get all the Oracle related information.

If Python is not installed, you can run the SQL scripts separately per DB instance:

`@collect-awr [days] [offset]`

Where [days] is the number of full days to collect, and [offset] is the number of days to shift back in time. For example, `@awr-collect 10 5` will collect reports between 15 and 5 days ago.

`@dbinfo` takes no parameters.

Windows is not (yet) supported and requires running the sql scripts separately (like described above)

## Requirements

- Oracle RDBMS 11g or higher, SQL*Plus configured
- Database instances up and running and listed in /etc/oratab or /var/opt/oracle/oratab (Solaris)
- Python 2 installed (to run dbcollect vs separate scripts)
- 'zip' and 'unzip' available on $ORACLE_HOME/bin/ (usually this is the case)
- SYS credentials
- AWR or Statspack installed and configured
- Retention at least 7 days (10080 minutes)
- Interval maximum 1 hour (60 minutes)
- On Windows: C:\Temp directory available (TEMP path can be changed in the collect-env.sql script)
- Some free temp space for the generated files (typically a few 100 MB)
- Free space in the current directory for the ZIP file(s)

## Known limitations and caveats

- The tablespaces report their default compression settings, which may not reflect the actual table compression
- Not all support files may be reported
- Backup files, logs etc may no longer exist but still be reported. Best effort.
- Very long names for files, tablespaces, disk groups etc may be truncated/wrapped
- Very large sized elements or very large amounts of objects may result in `####` notation and no longer be useful. Current limits are 999 Terabyte, 10,000 files and 1M objects which should be enough
- Newer Oracle versions may cause unreliable numbers

## Safety

- If you run as 'root', dbcollect switches to a non-root user early. By default this is 'oracle', use '-u user' to use another user
- The scripts only contain SELECT statements and SQL*Plus formatting/reporting commands. No data will be changed directly on the database
- The collect scripts can generate a large number of files in /tmp - usually a few hundred MB. Make sure there is enough space.

## License

_dbcollect_ is licensed under GPLv3. See "COPYING" for more info.

## Author

Bart Sjerps (bart &lt;at&gt; outrun &lt;dot&gt; nl) - with great contributions from my colleagues at DellEMC.<br>
Original collect-awr version and other improvements by Graham Thornton (oraclejedi &lt;at&gt; gmail &lt;dot&gt; com).



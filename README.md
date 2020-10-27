DBCollect - Oracle Database Info Collector
=

## Description

_dbcollect_ is a metadata collection tool for Oracle databases.

The main part is a Python tool that collects various system files and
the output of some commands, as well as AWR or Statspack reports for each
database instance, and other database information.

The results are collected in a ZIP file named (default):
`/tmp/dbcollect-<hostname>.zip`

## Prerequisites

On Enterprise Linux 6 (RHEL 6, OEL 6, CentOS 6) you need to have `python-argparse` installed:

`yum install python-argparse`

On IBM AIX, you need to install Python 2. You can get python for AIX from
[AIX Toolbox (IBM)](https://www.ibm.com/support/pages/aix-toolbox-linux-applications-overview)

On Solaris, Python should be already available.

On Enterprise Linux 7 (RHEL 7, OEL 7, CentOS 7), Python2 is installed by default including the argparse module.

Enterprise Linux 8 has not been tested yet but should work fine.

## Install

### Easy way

The easiest way to install _dbcollect_ is to run this command on your database host:

`curl https://raw.githubusercontent.com/outrunnl/dbcollect/master/scripts/install | python`

This will download _dbcollect_ and put it in /usr/local/bin (it asks for sudo access if you are not root).
It requires internet access via https.

### Manual install

You can download or inspect the installer first if needed. If you prefer to manually download _dbcollect_, download it from this link:

[latest dbcollect version](https://github.com/outrunnl/dbcollect/releases/latest)

Place _dbcollect_ in /usr/local/bin and make it executable:

`chmod 755 /usr/local/bin/dbcollect`

(alternatively you can run it via `python /usr/local/bin/dbcollect`)

`dbcollect` is a single `zipapp` package. If you prefer to unzip it first before running, for example:

```
cd /usr/local/bin
unzip dbcollect -d /usr/local/src/dbcollect
python /usr/local/src/dbcollect/dbcollect.py
```

## Info collected by dbcollect:

- AWR or Statspack reports for a default period of about 10 days
- Database configuration (such as version, dbname, database and system settings)
- Database file info (sizes and settings of datafiles, tempfiles, redo logs, control files etc)
- Additional database file info (backup, archive logs, flashback logs)
- Tablespace details, Segment sizes, AWR/Statspack details
- ASM disk group and disk info
- Init parameters
- Feature usage
- UNIX/Linux: CPU, memory, disks, network interfaces etc
- SAR: Binary SAR files (Linux) or SAR reports (UNIX)
- HP/UX: Not supported (let me know if you need it)
- Windows: Not yet supported (TBD)

More collectors may be added in the future.

## Usage

### Important note

By default, _dbcollect_ attempts to collect Oracle AWR reports in HTML format. For this,
Oracle requires Diagnostics Pack (see Oracle doc id 1490798.1).
_dbcollect_ can not directly determine if you have this license or not. As an indirect method, 
it checks the dba_feature_usage_statistics table whether "AWR Reports" has been used previously or not.
If this is NOT the case, dbcollect produces an error message "No prior AWR usage detected" and proceeds with the next database if any.

It is possible that you are licensed correctly but never used AWR reports on this specific database - in that case,
DBCollect thinks you are not licensed and gives up.

If you ARE licensed, you can run dbcollect with the --force option. DBcollect will only warn about the AWR detection and just generate the reports anyway.

**Use the `--force` flag ONLY if you are sure you are correctly licensed!
**

If you are NOT licensed for diagnostics pack then you can use Statspack instead (see section below)

More info on Oracle feature usage: [Oracle Feature Usage](https://oracle-base.com/articles/misc/tracking-database-feature-usage)

### Basic operation

In most cases you can just run

`dbcollect`

as 'oracle' user or root (assuming the database runs under user 'oracle')

When complete, a ZIP file will be created in the /tmp directory. This file contains the database overview and, by default, the last 10 days of AWR or Statspack reports. All temp files will be either cleaned up or moved into the ZIP archive.

### Oracle running as other user than 'oracle'

DBCollect by default switches to user 'oracle' if you run it as root. If you do NOT run as root, run it as the user that Oracle database runs as.
If you run as root and the database user is NOT 'oracle', use the -u/--user option:

`dbcollect --user dbuser`

Many systems have a split user configuration for Oracle clusterware (i.e. a `grid` user). This is fine as _dbcollect_ only needs the database user credentials.

Having more than one `oracle` user for running databases is currently not supported. Let me know if you need this.

### Statspack

By default, dbcollect attempts to run AWR reports but has a built-in protection against license violations
if no previous AWR usage can be detected. If you don't have Diagnostics/Tuning package,
you can run Statspack reports instead, provided statspack is running and collecting metrics:

`dbcollect --statspack`

Statspack is not configured by default on Oracle but requires initial setup.

To setup Statspack, see [Oracle-base: Statspack](https://oracle-base.com/articles/8i/statspack-8i)

After setup, you need to wait 7 to 10 days to let it collect performance information before running dbcollect.

### Changing collect period

By default, dbcollect collects the last 10 days of AWR/Statspack data.

To collect a longer period, use the --days option:

`dbcollect --days 14`

If you want to collect reports from a longer time ago (say, 20 days ago up to 10 days ago), use the offset option:

`dbcollect --days 10 --offset 10`

### Non-Linux (UNIX) systems

DBCollect now supports AIX and Solaris systems. You need to have Python 2 installed.

Windows is not (yet) supported.

## Requirements

- Oracle RDBMS 11g or higher, SQL*Plus configured (dbcollect may work fine with Oracle 10g, mileage may vary)
- Database instances up and running and listed in /etc/oratab or /var/opt/oracle/oratab (Solaris)
- Python 2
- SYS credentials (hence the 'oracle' user)
- AWR or Statspack installed and configured
- Retention at least 7 days (10080 minutes)
- Interval maximum 1 hour (60 minutes)
- Some free temp space for the generated files (typically a few 100 MB but can be larger depending on snapshot intervals and other factors)

## Known limitations and caveats

- The tablespaces report their default compression settings, which may not reflect the actual table compression
- Not all support files may be reported
- Backup files, logs etc may no longer exist but still be reported. Best effort.
- Very long names for files, tablespaces, disk groups etc may be truncated/wrapped
- Very large sized elements or very large amounts of objects may result in `####` notation and no longer be useful. Limits have been increased to insane values so this should not be a problem
- Newer Oracle versions (20c) may cause unreliable numbers

## Safety

A lot of safety guards have been built into _dbcollect_. It is designed to not require root access and only writes files to the /tmp directory by default. Even if it fails for some reason, no harm can be done.

- If you run as 'root', dbcollect switches to a non-root user early. By default this is 'oracle', use '-u user' to use another user.
- By default, SQL statements are removed from AWR reports as they could contain confidential information. Not available for Statspack.
- The scripts only contain SELECT statements and SQL*Plus formatting/reporting commands. No data will be changed directly on the database.
- The collect scripts can generate a large number of files in /tmp - usually a few hundred MB. Make sure there is enough space.
- In some cases, _dbcollect_ may fail or run with warnings or errors. This will not cause further issues except that not all required data is collected.

## Source code

dbcollect is packaged as a Python "zipapp" package which is a specially prepared ZIP file. You can unzip it with a normal unzip tool.
For example, listing the files in the package:

`unzip -l /usr/local/bin/dbcollect`

## Q&A

Q: Why is dbcollect written in Python 2? This is no longer supported!

A: Python 3 is not available by default on Linux (RHEL/OEL/CentOS). On EL6 I even had to backport support for Python 2.6. I plan to make it work with both python 2 and 3 in the future.

Q: Does dbcollect gather confidential data?

A: dbcollect only retrieves system configuration files, SAR/AWR/Statspack etc. In AWR and Statspack however, a number of SQL queries (statements) can be visible. For AWR, dbcollect removes sections containing SQL statements by default to prevent collecting pieces of potentially confidential data. The values of bind parameters are not visible.

Q: dbcollect appears to be a binary package. How do I know what it is doing?

A: dbcollect is actually a Python ZipApp package. You can unzip it using unzip and list its contents, the Python code and SQL scripts can be extracted:

```bash
# List the files in the package
unzip -l dbcollect
# Unpack (to subdirectory)
unzip dbcollect -d dbcollect-source
```

Q: How do I know my download has not been tampered with?

A: If you downloaded dbcollect from github using https, you should be good. If you want to make sure, get the MD5 hash and I can check for you if it is the correct one:
```
md5sum dbcollect
```

Q: I want to check what information dbcollect has gathered

A: Inspect the zip file `/tmp/dbcollect-<hostname>.zip` and check its contents.

## License

_dbcollect_ is licensed under GPLv3. See "COPYING" for more info or go to [GPLv3+ License Info](https://www.gnu.org/licenses/gpl-3.0.html)

## Author

Bart Sjerps (bart &lt;at&gt; outrun &lt;dot&gt; nl) - with great contributions from others






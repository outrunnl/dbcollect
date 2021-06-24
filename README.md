DBCollect - Oracle Database Info Collector
======================

![logo](https://github.com/outrunnl/dbcollect/blob/master/artwork/dbcollect-logo.png)


## Description

_dbcollect_ is a metadata collection tool for Oracle databases.

It is written in Python, and collects various OS configuration files and
the output of some system commands, as well as AWR or Statspack reports for each
database instance, and other database information.

The results are collected in a ZIP file named (default):
`/tmp/dbcollect-<hostname>.zip`

## Prerequisites

On Enterprise Linux 6 (RHEL 6, OEL 6, CentOS 6) you need to have `python-argparse` installed:

`yum install python-argparse`

If you cannot install argparse, check out `dbcollect-wrapper` from the `scripts` directory.

On IBM AIX, you need to install Python 2. You can get python for AIX from
[AIX Toolbox (IBM)](https://www.ibm.com/support/pages/aix-toolbox-linux-applications-overview)

On Solaris, Python should be already available.

HP-UX has not yet been tested (mileage may vary, let me know if you want to help testing)

On Enterprise Linux 7 (RHEL 7, OEL 7, CentOS 7), Python2 is installed by default including the argparse module.

Enterprise Linux 8 (RHEL 8, OEL 8) are not yet supported (TBD).

Older Linux versions (RHEL5) do not work unless there is a more recent version of Python on the system.

## Install

### Easy way

The easiest way to install _dbcollect_ is to run this command on your database host:

```
curl https://raw.githubusercontent.com/outrunnl/dbcollect/master/scripts/download | python
sudo mv dbcollect /usr/local/bin
```

This will download _dbcollect_ and put it in /usr/local/bin (it asks for sudo access if you are not root).
It requires internet access via https.

You may want to inspect `download` first before running it:
```
curl https://raw.githubusercontent.com/outrunnl/dbcollect/master/scripts/download | less
```

### Manual install

You can download or inspect the installer first if needed. If you prefer to manually download _dbcollect_, download it from this link:

[latest dbcollect version](https://github.com/outrunnl/dbcollect/releases/latest)

Place _dbcollect_ in /usr/local/bin and make it executable:

`chmod 755 /usr/local/bin/dbcollect`

(alternatively you can run it via `python /usr/local/bin/dbcollect`)

`dbcollect` is a single `zipapp` package. If you prefer to unzip it first before running, for example:

```
cd /usr/local/bin
# Inspect only
unzip -v dbcollect
# Unpack in another folder
unzip dbcollect -d /usr/local/src/dbcollect
# Run it from other folder
python /usr/local/src/dbcollect/dbcollect.py
```

## Updating

dbcollect has a self-updating feature that fetches a new version if available from github. It requires https access to github.com.
To use this run
```
dbcollect --update
```
If you don't run this as root (or using sudo) you manually have to move /tmp/dbcollect to /usr/local/bin (or another location in $PATH)

## Info collected by dbcollect:

- AWR or Statspack reports for a default period of about 10 days
- Database configuration (such as version, dbname, database and system settings)
- Database file info (sizes and settings of datafiles, tempfiles, redo logs, control files etc)
- Additional database file info (backup, archive logs, flashback logs)
- Tablespace details, Segment sizes, AWR/Statspack details
- ASM disk group and disk info
- Init parameters
- Feature usage
- Linux: CPU, memory, disks, network interfaces etc
- AIX, Solaris (SPARC): CPU, memory, limited other info
- SAR: Binary SAR files (Linux) or SAR reports (UNIX) (Linux SAR provides much more detail)
- HP/UX: Not supported (let me know if you need it)
- Windows: Not yet supported (TBD)

More collectors may be added in the future.

## Usage

### Important note

Ideally, _dbcollect_ collects Oracle AWR reports in HTML format as HTML can be processed (parsed) reliably.
It can also generate Statspack reports. This is how _dbcollect_ decides which reports to produce:

Oracle AWR reports require Diagnostics Pack (see Oracle doc id 1490798.1).
_dbcollect_ can not directly determine if you have this license or not - it checks the dba_feature_usage_statistics
table whether "AWR Reports" has been used previously or not, and falls back to Statspack otherwise, unless the ```--force``` flag
has been specified. The decision flow is as follows:

1. Check if 'AWR Reports' is a feature that has been used before. If so, use AWR reports
2. If AWR usage is not detected but the ```--force``` flag has been specified, use AWR reports
3. If AWR usage is not detected and no ```--force``` flag is specified, check if STATSPACK is available. If so, use Statspack
4. If we get to this point, give up for this instance and issue an error, continue with the next instance

So if you ARE licensed but _dbcollect_ complains, you can run dbcollect with the --force option. 
DBcollect will only warn about the AWR detection and just generate the reports anyway.

**Use the `--force` flag ONLY if you are sure you are correctly licensed!
**

If you are NOT licensed for diagnostics pack then you can use Statspack instead (see section below)

More info on Oracle feature usage: [Oracle Feature Usage](https://oracle-base.com/articles/misc/tracking-database-feature-usage)

### Basic operation

Get a list of options:

`dbcollect -h`

In most cases you can just run

`dbcollect`

as 'oracle' user or root (assuming the database runs under user 'oracle')

If you get this error:
```ERROR    : ZIP file already exists: /tmp/dbcollect-db02.lan.zip```

Run `dbcollect --delete` to clean up the old zipfile.

When complete, a ZIP file will be created in the /tmp directory. This file contains the database overview and, by default, the last 10 days of AWR or Statspack reports. All temp files will be either cleaned up or moved into the ZIP archive.

### Oracle running as other user than 'oracle'

DBCollect by default switches to user 'oracle' if you run it as root. If you do NOT run as root, run it as the user that Oracle database runs as.
If you run as root and the database user is NOT 'oracle', use the -u/--user option:

`dbcollect --user dbuser`

Many systems have a split user configuration for Oracle clusterware (i.e. a `grid` user). This is fine as _dbcollect_ only needs the database user credentials.

Having more than one `oracle` user for running databases is currently not supported. Let me know if you need this.
A workaround for systems with multiple Oracle users:

```ps -eo user,args | awk '$2 ~ /ora_pmon_/ {print $1}' | xargs -I% dbcollect --user % --output /tmp/dbcollect-% <other options>```

This will create multiple zip files (one for each active user).

### Statspack

If no AWR usage is detected and no `--force` flag is used, _dbcollect_ checks for STATSPACK data.
Statspack is not configured by default on Oracle but requires initial setup.

To setup Statspack, see [Oracle-base: Statspack](https://oracle-base.com/articles/8i/statspack-8i)

After setup, you need to wait 7 to 10 days to let it collect performance information before running dbcollect.

### Changing collect period

By default, _dbcollect_ collects the last 10 days of AWR/Statspack data. SAR (sysstat) usually goes back up to 31 days (all SAR files are collected).

To collect a longer AWR/Statspack reports period, use the --days option (up to 999 days):

`dbcollect --days 14`

If you want to collect reports from a longer time ago (say, 20 days ago up to 10 days ago), use the offset option:

`dbcollect --days 10 --offset 10`

### Non-Linux (UNIX) systems

DBCollect now supports AIX and Solaris systems. You need to have Python 2 installed.

Windows and HP-UX are not (yet) supported.

## Requirements

- Oracle RDBMS 10g or higher
- Enterprise Linux 6 or 7, Solaris 11, IBM AIX 7
- Python 2
- Database instances up and running and listed in /etc/oratab or /var/opt/oracle/oratab (Solaris)
- SYS credentials (hence the 'oracle' user)
- AWR or Statspack installed and configured
- Retention should be at least 7 days (10080 minutes) for a reasonable period of workload data
- AWR Snapshot Interval: maximum 1 hour (60 minutes)
- Some free temp space for the generated files (typically a few hundred MB, but can be larger depending on snapshot intervals and other factors)

## Known limitations and caveats

- Backup files, logs etc may no longer exist but still be reported, depending on backup catalog accuracy. Best effort.
- Very long names for files, tablespaces, disk groups etc may be truncated/wrapped
- Very large sized elements or very large amounts of objects may result in `####` notation and no longer be useful. Limits have been increased to insane values so this should not be a problem
- Newer Oracle versions (20c and up) may cause unreliable numbers, not yet tested
- Oracle RAC sometimes is very slow with generating AWR reports. Known issue. Be patient. See [Troubleshooting](#Troubleshooting).

## Safety

A lot of safety guards have been built into _dbcollect_. It is designed to not require root access and only writes files to the /tmp directory by default. Even if it fails for some reason, no harm can be done.

More info can be found in [DBCollect Security](https://github.com/outrunnl/dbcollect/blob/master/SECURITY.md)

## Source code

dbcollect is packaged as a Python "zipapp" package which is a specially prepared ZIP file. You can unzip it with a normal unzip tool.
For example, listing the files in the package:

`unzip -l /usr/local/bin/dbcollect`

## Q&A

Q: Why is dbcollect written in Python 2? This is no longer supported!

A: Python 3 is not available by default on many older systems, i.e. Linux (RHEL/OEL/CentOS), Solaris. On EL6 I even had to backport support for Python 2.6. I plan to make it work with both python 2 and 3 in the future.

Q: How long will it take to run _dbcollect_ ?

A: This mostly depends on how many AWR/Statspack reports need to be generated. Collecting the OS information usually only takes a few seconds. For normal environments, an AWR report (HTML) takes a about 1-2 seconds, Statspack even less. For a single instance environment, 10 day collect period, 1 hour interval, the amount of reports is about 240 so _dbcollect_ will run for under 10 minutes. There are some known Oracle issues with AWR generation resulting in much longer times. The latest version of _dbcollect_ predicts the remaining time so you have an idea.

Q: Does dbcollect gather confidential data?

A: dbcollect only retrieves system configuration files, SAR/AWR/Statspack etc. In AWR and Statspack however, a number of SQL queries (statements) can be visible. For AWR, dbcollect can remove sections containing SQL statements to prevent collecting pieces of potentially confidential data. The values of bind parameters are not visible. See the ```--strip``` option.

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

## Troubleshooting

Tip: if something fails, run dbcollect with the ```-D``` (debug) option. This will show the content of exception debug messages and print the full dbcollect.log logfile when finished.

```ERROR    : Skipping <SID>: No prior AWR usage or Statspack detected (try --force)```

dbcollect refuses to generate AWR reports because it cannot determine if you have a proper (diagnostics pack) license. You can force it with the ```--force``` option if you are sure you have the license (note that during an audit, Oracle can determine you have used the feature in the past). See [Important Note](#important-note)

```
ERROR    : IO Error retrieving /var/log/sa/sa01: Permission denied```

Solution: dbcollect runs as non-root (see [Security](https://github.com/outrunnl/dbcollect/blob/master/SECURITY.md)) and cannot read the SAR files.
You can solve this (temporarily) by running ```chmod o+r /var/log/sa/sa*```

IO Errors on other files than SAR:

Some systems have non-standard security policies, preventing dbcollect to read these files. It may be undesirable to change the permissions with ```chmod```. In these cases you can use file access control lists to set an ACL permission without changing the basic permissions. The command is
```setfacl -m u:oracle:- <file(s)>``` - assuming the database user under which dbcollect runs is oracle.
If these files are 'pseudo' files (such as in /sys, /proc etc) the permissions will be reset to normal at the first reboot.

```INFO     : python-lxml package not found, fallback to slower xml package```

This is just informational. If you want to speed things up a bit, do ```yum install python-lxml```.

```ERROR: Unknown platform```

You're trying to run dbcollect on a platform that is not supported (Possibly HP-UX, Windows or Mac?)

```ERROR: Cannot access Oracle inventory```

dbcollect uses the Inventory to find ORACLE_HOME directories. Without this, not all Oracle instances may be detected (only those with a valid oratab entry)

```ERROR: Oracle Error```

Something went wrong running an SQLPlus script. Usually the error message from SQLPlus is also printed.

```ERROR: Skipping instance <SID> (cannot connect)```

An Oracle instance is detected and found to be running but the state (open, mounted, started, etc) cannot be determined.

```ERROR: Parsing error in <AWR file>, not stripped```

To strip SQL text from AWR reports, dbcollect uses an XML parser. The parser reported errors during parsing (maybe the AWR html is corrupted). The AWR report is saved without modifications (this means SQL text may still be there)

```ERROR: Storing logfile failed: <file>```

dbcollect cannot save the logfile ```/tmp/dbcollect.log``` in the zip file for some reason. Try removing an existing ```/tmp/dbcollect.log``` file first.

    WARNING  : Oracle status check failed, sqlplus return code 1
    WARNING  : SQL*Plus login failed, continuing with next SID

dbcollect cannot login as sysdba to the database instance. Maybe because it uses the wrong user id (use ```--user <oracle_user>```)

    Requires Python 2 (2.6 or higher, EL6)

You are attempting to run dbcollect on a legacy system with RHEL/OEL 5.x or another UNIX system with a Python version before 2.6. This is not supported.

### Generating the AWR reports takes a very long time

This is especially the case if you run _dbcollect_ on Oracle RAC. There are a number of known issues that cause it to be very slow. I have observed up to 20 seconds per AWR report (usually about 0.5 seconds) making _dbcollect_ run for over an hour or more for a typical 10-day, 1-hour interval, single database cluster.
Check Support notes for fixes and workarounds: 2404906.1, 2565465.1, 2318124.1, 29932310.8, 2148489.1, 29470291.8. Or be very patient.

## License

_dbcollect_ is licensed under GPLv3. See "COPYING" for more info or go to [GPLv3+ License Info](https://www.gnu.org/licenses/gpl-3.0.html)

## Author

Bart Sjerps (bart &lt;at&gt; outrun &lt;dot&gt; nl) - with great contributions from others






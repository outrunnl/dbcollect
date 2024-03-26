DBCollect - Oracle Database Info Collector
======================

![logo](https://github.com/outrunnl/dbcollect/blob/master/artwork/dbcollect-logo.png)


## Description

_dbcollect_ is a metadata collection tool for Oracle databases, providing workload and config data from database hosts for:

* Dell LiveOptics
* Dell's internal Splunk-based Workload Analyzer for Oracle (used by Oracle specialists at Dell)
* DBLytics (The advanced DB workload analyzer tool I have developed - more info TBD)

It is written in Python, and collects various OS configuration files and
the output of some system commands, as well as AWR or Statspack reports for each
database instance, and other database information.

The results are collected in a ZIP file named (default):
`/tmp/dbcollect-<hostname>.zip`

For LiveOptics and Dell's Workload Analyzer, the per-database directories in the ZIP file contain all files you need to upload to the reporting tools.

For the advanced analyzer, send the entire ZIP file (via secure FTP or other means).

## Installing and usage

See [INSTRUCTIONS](https://github.com/outrunnl/dbcollect/blob/master/INSTRUCTIONS.md) for information on installation and usage.

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
- HP/UX: Experimental support
- Windows: Not yet supported (TBD)

More collectors may be added in the future.

### Important note

Ideally, _dbcollect_ collects Oracle AWR reports in HTML format as HTML can be processed (parsed) reliably.
It can also generate Statspack reports. This is how _dbcollect_ decides which reports to produce:

Oracle AWR reports require Diagnostics Pack (see Oracle doc id 1490798.1).
_dbcollect_ can not directly determine if you have this license or not - it checks the dba_feature_usage_statistics
table whether "AWR Reports" has been used previously or not, and falls back to Statspack otherwise, unless the ```--force-awr``` flag
has been specified. The decision flow is as follows:

1. Check if 'AWR Reports' is a feature that has been used before. If so, use AWR reports
2. If AWR usage is not detected but the ```--force-awr``` flag has been specified, use AWR reports
3. If AWR usage is not detected and no ```--force-awr``` flag is specified, check if STATSPACK is available. If so, use Statspack
4. If AWR usage is not detected, no ```--force-awr``` has been specified and no statspack reports are available, but ```--ignore``` is specified, ignore and continue to the next
5. If AWR usage is not detected, no ```--force-awr``` has been specified and no statspack reports are available, abort with an error

So if you ARE licensed for Diagnostics Pack but _dbcollect_ complains, you can run dbcollect with the --force-awr option.
DBcollect will only warn about the AWR detection and just generate the reports anyway.

** Use the `--force-awr` flag ONLY if you are sure you are correctly licensed! **

If you are NOT licensed for diagnostics pack then you can use Statspack instead (see section below)

More info on Oracle feature usage: [Oracle Feature Usage](https://oracle-base.com/articles/misc/tracking-database-feature-usage)

### Oracle running as other user than 'oracle'

DBCollect by default switches to the first user it detects that runs a regular database instance, like `ora_pmon_<sid>`. Usually this is the 'oracle' user. If you do NOT run as root, run it as the user that Oracle database runs as, or a user with `dba` privileges (connect as sysdba).

If you run as root and want to specify a particular user, use the -u/--user option:

`dbcollect --user dbuser`

Many systems have a split user configuration for Oracle clusterware (i.e. a `grid` user). This is fine as _dbcollect_ only needs the database user credentials.

Having more than one `oracle` user for running databases should work as long as they share the `dba` privileges (i.e., they can all connect to all instances as sysdba).

Running instances with different users not sharing dba privileges is not supported (contact me for a workaround).


### Statspack

If no AWR usage is detected and no `--force-awr` flag is used, _dbcollect_ checks for STATSPACK data.
Statspack is not configured by default on Oracle but requires initial setup.

To setup Statspack, see [Oracle-base: Statspack](https://oracle-base.com/articles/8i/statspack-8i)

After setup, you need to wait 7 to 10 days to let it collect performance information before running dbcollect.

### Changing collect period

By default, _dbcollect_ collects the last 10 days of AWR/Statspack data. SAR (sysstat) usually goes back up to 31 days (all SAR files are collected).

To collect a longer AWR/Statspack reports period, use the --days option (up to 999 days):

`dbcollect --days 14`

If you want to collect reports from a longer time ago (say, 20 days ago up to 10 days ago), use the offset option:

`dbcollect --days 20 --end_days 10`

** Changed: --days now always means the number of days ago to START the collect period. --end_days means the day to STOP the collect period 

### Non-Linux (UNIX) systems

DBCollect now supports AIX and Solaris systems, and HP-UX has experimental support. You need to have Python installed (at least version 2.6).

Windows is not (yet) supported.

## Requirements

See [INSTRUCTIONS](https://github.com/outrunnl/dbcollect/blob/master/INSTRUCTIONS.md) for information on requirements.

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

Q: Why can't we just send some AWR reports?

A: AWR reports are great but have a few problems and limitations for our purpose:

* AWR only provides performance and limited configuration metrics. There is no database size/config information such as sizes of tablespaces, redo logs, temp files, segments, ASM disks/diskgroups, archive/flashback/bct files
* No OS configuration or hardware information (such as CPU type & model)
* No disk/network configuration
* No UNIX SAR/sysstat performance data
* No compression, backup, archiving details
* AWRs are sometimes generated using non-English locale (cannot be parsed)
* AWRs are sometimes generated in txt format instead of html (hard to parse, error-prone)
* AWRs are sometimes provided as RAC versions (completely different layout, hard to parse)
* Usually only a few AWRs are provided, sometimes with a very large interval (many hours or even days) which is not detailed enough to do accurate sizings or performance analysis
* No way to know if there are other instances on the same system for which we need to know details

Q: Is dbcollect safe to run?

A: dbcollect is designed to run as non-root user but it has to be the oracle user or a user with sysdba privileges. The SQL scripts only contain SELECT statements so they cannot modify database data. The Python tools cannot delete/overwrite any file except in `/tmp` or the output ZIP file otherwise specified in the arguments. External commands are not executed as root and are verified to only gather system info, not modify anything. CPU consumption is limited by default to 50%. These restrictions should make one confident that dbcollect is safe to run on production systems.

Q: Why is dbcollect written in Python 2? This is no longer supported!

A: Python 3 is not available by default on many older systems, i.e. Linux (RHEL/OEL/CentOS), Solaris. On EL6 I even had to backport support for Python 2.6.
Update: dbcollect now works on both Python 2 and Python 3.

Q: How long will it take to run _dbcollect_ ?

A: This mostly depends on how many AWR/Statspack reports need to be generated and how many CPUs are available. Collecting the OS information usually only takes a few seconds. For normal environments, an AWR report (HTML) takes a about 1-2 seconds, Statspack even less. For a single instance environment, 10 day collect period, 1 hour interval, the amount of reports is about 240 so _dbcollect_ will run for under 10 minutes. There are some known Oracle issues with AWR generation resulting in much longer times. The latest version of _dbcollect_ predicts the remaining time so you have an idea.
As of version 1.11, _dbcollect_ runs AWR reports in parallel on each instance, making it much faster.

Q: Does dbcollect gather confidential data?

A: dbcollect only retrieves system configuration files, SAR/AWR/Statspack etc. In AWR and Statspack however, a number of SQL queries (statements) can be visible. For AWR, dbcollect can remove sections containing SQL statements to prevent collecting pieces of potentially confidential data. The values of bind parameters are not visible. See the ```--strip``` option. Passwords or user credentials are never collected.

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

See the [TROUBLESHOOTING](https://github.com/outrunnl/dbcollect/blob/master/TROUBLESHOOTING.md) guide.

## License

_dbcollect_ is licensed under GPLv3. See "COPYING" for more info or go to [GPLv3+ License Info](https://www.gnu.org/licenses/gpl-3.0.html)

## Author

Bart Sjerps (bart &lt;at&gt; dirty-cache &lt;dot&gt; com) - with great contributions from others

# Troubleshooting

## Debug

Tip: if something fails, run dbcollect with the ```-D``` (debug) option. This will show the content of exception debug messages and print the full dbcollect.log logfile when finished.

## AWR usage not detected

```ERROR    : Skipping <SID>: No prior AWR usage or Statspack detected (try --force-awr)```

dbcollect refuses to generate AWR reports because it cannot determine if you have a proper (diagnostics pack) license. You can force it with the ```--force-awr``` option if you are sure you have the license (note that during an audit, Oracle can determine you have used the feature in the past). See [Important Note](https://github.com/outrunnl/dbcollect/blob/master/README.md#important-note)

## Permission denied
```
ERROR    : IO Error retrieving /var/log/sa/sa01: Permission denied
```

Solution: dbcollect runs as non-root (see [Security](https://github.com/outrunnl/dbcollect/blob/master/SECURITY.md)) and cannot read the SAR files.
You can solve this (temporarily) by running ```chmod o+r /var/log/sa/sa*```

## Other IO Errors

IO Errors on other files than SAR:

Some systems have non-standard security policies, preventing dbcollect to read these files. It may be undesirable to change the permissions with ```chmod```. In these cases you can use file access control lists to set an ACL permission without changing the basic permissions. The command is
```setfacl -m u:oracle:- <file(s)>``` - assuming the database user under which dbcollect runs is oracle.
If these files are 'pseudo' files (such as in /sys, /proc etc) the permissions will be reset to normal at the first reboot.

## Python-LXML package

```INFO     : python-lxml package not found, fallback to slower xml package```

This is just informational. If you want to speed things up a bit, do ```yum install python-lxml```.

## Unknown Platform

```ERROR: Unknown platform```

You're trying to run dbcollect on a platform that is not supported (Possibly HP-UX, Windows or Mac?)

## Oracle Inventory

```ERROR: Cannot access Oracle inventory```

dbcollect uses the Inventory to find ORACLE_HOME directories. Without this, not all Oracle instances may be detected (only those with a valid oratab entry)

## Oracle Error

```ERROR: Oracle Error```

Something went wrong running an SQLPlus script. Usually the error message from SQLPlus is also printed.

## Oracle Instance connect problems

```ERROR: Skipping instance <SID> (cannot connect)```

An Oracle instance is detected and found to be running but the state (open, mounted, started, etc) cannot be determined.

Known to happen if there are problems with detecting the correct ORACLE_HOME (i.e., due to usage of symbobolic links)

## Parsing Error in AWR file, not stripped

```ERROR: Parsing error in <AWR file>, not stripped```

To strip SQL text from AWR reports, dbcollect uses an XML parser. The parser reported errors during parsing (maybe the AWR html is corrupted). The AWR report is saved without modifications (this means SQL text may still be there)

## Errors creating/storing the logfile

```ERROR: Storing logfile failed: <file>```

dbcollect cannot save the logfile ```/tmp/dbcollect.log``` in the zip file for some reason. Try removing an existing ```/tmp/dbcollect.log``` file first.

## Oracle status check warnings

    WARNING  : Oracle status check failed, sqlplus return code 1
    WARNING  : SQL*Plus login failed, continuing with next SID

dbcollect cannot login as sysdba to the database instance. Maybe because it uses the wrong user id (use ```--user <oracle_user>```)

## Python version

```Requires Python 2 (2.6 or higher, EL6)```

You are attempting to run dbcollect on a legacy system with RHEL/OEL 5.x or another UNIX system with a Python version before 2.6. This is not supported.

## Python: No such file or directory

```/usr/bin/env: ‘python’: No such file or directory```

You are probably running on Enterprise Linux 8 - which by default has python 3 installed, but 'python' is not set to run python3. Run ```alternatives --set python /usr/bin/python3``` so that 'python' starts python3. The same problem has been observed on Solaris/SPARC in some cases.

## Error importing Python-argparse

```
ERROR: Cannot import module 'argparse'. Please install python-argparse first:
yum install python-argparse
```

On Enterprise Linux, python-argparse is not installed by default (but in most cases it is there as other packages require it). Install python-argparse (as root) and retry. If you cannot install argparse (maybe you have no root access), check out `dbcollect-wrapper` from the `scripts` directory.

## Job processor timeout

```ERROR    : Exception in job_processor: Job processor timeout```

This happens when a query issued to SQL*Plus takes longer than the timeout period (default 10 minutes). It is usually a sign that the database workload is very high or maybe the instance is hanging (such as when the archive log destination is full).
You can increase the timeout using ```--timeout <t>``` where t is timeout in minutes.

Update: Sometimes a SELECT on DBA_FREE_SPACE or CDB_FREE_SPACE in Oracle is very slow, causing the dbinfo scripts to run very long which in turn causes the job processors to timeout. Possible fix:

```
SQL> purge dba_recyclebin;
SQL> EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
SQL> EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
```

## Generating the AWR reports takes a very long time

This is especially the case if you run _dbcollect_ on Oracle RAC. There are a number of known issues that cause it to be very slow. I have observed up to 20 seconds per AWR report (usually about 0.5 seconds) making _dbcollect_ run for over an hour or more for a typical 10-day, 1-hour interval, single database cluster.
Check Support notes for fixes and workarounds: 2404906.1, 2565465.1, 2318124.1, 29932310.8, 2148489.1, 29470291.8. Or be very patient.

Update: As of version 1.11, _dbcollect_ runs multiple AWR reports in parallel for each instance, making it much faster, by default 50% of CPUs. To use all available CPUs, use ```--tasks 0``` (note that CPU load will likely go to 100%, be careful)

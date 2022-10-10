# Installation

## Notes

_dbcollect_ is a tool written in Python and distributed as a Python "ZipApp" package. The only thing you need to do to install it, is put it somewhere in the PATH and make it executable.


## Easy way

Assuming the prerequisites are met, the easiest way to install the latest version of _dbcollect_ is to run the downloader command on your host and move it to $PATH:

```
# This requires internet access via https
# Inspect downloader (optional)
curl https://raw.githubusercontent.com/outrunnl/dbcollect/master/scripts/download | less

# Download using downloader
curl https://raw.githubusercontent.com/outrunnl/dbcollect/master/scripts/download | python

# Move it to /usr/local/bin
sudo mv dbcollect /usr/local/bin

# Or move it to the current user's $HOME/bin (if it exists, usually user 'oracle'):
mv dbcollect $HOME/bin/
```

## Prerequisites

* Python 2.6 or higher
* Python-argparse (is usually included in the Python distribution except for very old versions)
* Enterprise Linux 6, 7 or 8, Solaris 11, IBM AIX 7
* Some free space in /tmp
* Oracle RDBMS 10g or higher (optional)
* Diagnostics pack license OR statspack configured on the database(s)
* Access to the 'oracle' special user ('root' not required)
* Database instances up and running and listed in /etc/oratab or /var/opt/oracle/oratab (Solaris) OR detectable via ORACLE_HOMES listed in the Oracle Inventory
* SYS credentials (hence the 'oracle' user requirement)

### Linux

On Enterprise Linux 7 (RHEL 7, OEL 7, CentOS 7), Python2 is installed by default including the argparse module.

Enterprise Linux 8 (RHEL 8, OEL 8) should now work fine as dbcollect is Python3 compatible. 'python' may not be configured by default, you can set 'python' to use python3:

```alternatives --set python /usr/bin/python3```

Older Linux versions (RHEL5) do not work unless there is a more recent version of Python on the system.

### AIX

On IBM AIX, you need to install Python first. You can get python for AIX from
[AIX Toolbox (IBM)](https://www.ibm.com/support/pages/aix-toolbox-linux-applications-overview)

### SPARC/Solaris

On Solaris, Python should be already available. It may be an older version.

### HP-UX

HP-UX has not yet been tested (mileage may vary, let me know if you want to help testing)

### Windows

_dbcollect_ does not yet support Windows. Let me know if you need it.

### Manual install

You can download or inspect the installer first if needed. If you prefer to manually download _dbcollect_, download it from this link:

[latest dbcollect version](https://github.com/outrunnl/dbcollect/releases/latest)

Place _dbcollect_ in /usr/local/bin or $HOME/bin and make it executable:

`chmod 755 /usr/local/bin/dbcollect`

(alternatively you can run it via `python /usr/local/bin/dbcollect`)

### Updating

```
# Update dbcollect:
dbcollect --update
# Without root access, the new version will be saved as /tmp/dbcollect.
# Move it manually to the required location.
```

### Running

In the majority of cases, simply run _dbcollect_ and it will run with default options. More options listed below.
```
# Run with default options (run as root or oracle user)
dbcollect

# List available options (help)
dbcollect -h

# Version info
dbcollect -V

# Force using AWR even if license is not detected:
dbcollect --force-awr

# Overwrite previous ZIP file:
dbcollect --overwrite

# Write ZIP file with different filename
dbcollect --filename my-dbcollect.zip

# Non-standard Oracle user (only needed if running as root)
dbcollect --user sap

# Collect more than 10 days of AWR data (if available)
dbcollect --days 31

# Shift collect period so you pick up from 30 days ago to 10 days ago
dbcollect --offset 10 --days 20

# Remove all SQL code from AWR reports (not for statspack)
dbcollect --strip

# Exclude one or more problem databases
dbcollect --exclude probdb1,probdb3

# Limit amount of concurrent AWR collection tasks (CPUs)
dbcollect --tasks 2

```
When complete, a ZIP file will be created in the /tmp directory. This file contains the database overview and, by default, the last 10 days of AWR or Statspack reports. All temp files will be either cleaned up or moved into the ZIP archive.

Please send this ZIP file to the person who requested it.


### Usage for Live Optics or SPLUNK based reporting

The data collected by _dbcollect_ can be used for uploading to Dell LiveOptics (Oracle Database reporting) or the Dell internal SPLUNK Oracle reporting (Dell employees only). For this, unzip the ZIP file and upload the folder containing Oracle data: ```<hostname>/oracle/<instance>/...``` for each instance required.

### More info

The dbcollect ZipApp package contains everything such as Python files and SQL scripts in a single file.

It is a standard ZIP file - only prepended with a Python "shebang":

```#!/usr/bin/env python```

For inspection you can unzip the package using a standard ZIP tool. It is not recommended to run _dbcollect_ in any other way than via the distributed package. Although it works, avoid using `git clone` or other ways to run it from the github sources.



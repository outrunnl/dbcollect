## Installation

### Notes

_dbcollect_ is a tool written in Python and distributed as a Python "ZipApp" package. The only thing you need to do to install it, is put it somewhere in the PATH and make it executable.


### Easy way

The easiest way to install the latest version of _dbcollect_ is to run the downloader command on your host and move it to $PATH:

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

# Write ZIP file to different location
dbcollect --output my-dbcollect.zip

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

# Limit amount of concurrent AWR collection tasks
dbcollect --tasks 2

```
When complete, a ZIP file will be created in the /tmp directory. This file contains the database overview and, by default, the last 10 days of AWR or Statspack reports. All temp files will be either cleaned up or moved into the ZIP archive.

Please send this ZIP file to the person who requested it.


### More info

The dbcollect ZipApp package contains everything such as Python files and SQL scripts in a single file.

It is a standard ZIP file - only prepended with a Python "shebang":

```#!/usr/bin/env python```

For inspection you can unzip the package using a standard ZIP tool. It is not recommended to run _dbcollect_ in any other way than via the distributed package. Although it works, avoid using `git clone` or other ways to run it from the github sources.



# Live Optics Howto

## Overview

_dbcollect_ can generate the input for Dell Live Optics as well as the internal SPLUNK based Oracle workload report system. This document explains how to use this feature.

## Collecting data

To use _dbcollect_ with Live Optics, there is no need to download the Live Optics AWR generation scripts (they are already part of _dbcollect_). The only thing you need to do is run _dbcollect_ with the ```--splunk``` option on the database host you want to generate data for:

```
dbcollect --splunk
```

Further follow the standard instructions for using _dbcollect_.

See [INSTRUCTIONS](https://github.com/outrunnl/dbcollect/blob/master/INSTRUCTIONS.md) for information on installation and usage.

## Uploading to Live Optics

The ZIP file created as ```/tmp/dbcollect-<hostname>.zip``` contains all files that need to be uploaded to Live Optics. However, you need to unzip the files for the database you need as Live Optics does not understand the layout of files in the ZIP archive. In the ZIP file you will find a directory ```[hostname]/oracle/[instance]/``` for each Oracle instance detected on the host. This directory contains everything that needs to be uploaded to Live Optics.

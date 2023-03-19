"""
archive.py - Manage DBCollect ZIP archives
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, logging, errno
from zipfile import ZipFile, ZIP_DEFLATED
from lib.functions import saferemove
from lib.errors import ZipCreateError

class Archive():
    """A wrapper around zipfile
    Makes sure it always contains the comment which shows the magic string for dbcollect
    On close it picks up the syscollect logfile
    Files and strings are prefixed with the hostname to avoid making a mess un unzip
    """
    zip = None
    def __init__(self, path, logpath, version, overwrite=False):
        self.prefix  = os.uname()[1]
        self.path    = path
        self.logpath = logpath
        if os.path.exists(self.path) and not overwrite:
            raise ZipCreateError("ZIP file already exists")
        try:
            self.zip = ZipFile(self.path,'w', ZIP_DEFLATED, allowZip64=True)
        except OSError as e:
            raise ZipCreateError("Cannot create zipfile")
        comment = 'dbcollect version={0} hostname={1}'.format(version, self.prefix)
        self.zip.comment = comment.encode('utf-8')
    def __del__(self):
        if not self.zip:
            return
        try:
            if os.path.isfile(self.logpath):
                self.zip.write(self.logpath,os.path.join(self.prefix, 'dbcollect.log'))
        except OSError as e:
            logging.error("Storing logfile failed: %s", e)
        try:
            saferemove(self.logpath)
        except Exception as e:
            logging.warning("Removing logfile failed: %s", e)
        self.zip.close()
    def store(self, path, tag=None, ignore=False):
        if tag:
            fulltag = os.path.join(self.prefix, tag)
        else:
            fulltag = os.path.join(self.prefix, path.lstrip('/'))
        if not os.path.isfile(path):
            logging.debug("Skipping %s (nonexisting)", path)
            return
        try:
            self.zip.write(path, fulltag)
        except OSError as e:
            if not ignore:
                logging.error("OS Error retrieving %s: %s", e.filename, os.strerror(e.errno))
        except IOError as e:
            if not ignore:
                logging.error("IO Error retrieving %s: %s", e.filename, os.strerror(e.errno))
    def move(self, path, tag=None):
        self.store(path, tag)
        saferemove(path)
    def writestr(self, tag, data):
        try:
            self.zip.writestr(os.path.join(self.prefix, tag.lstrip('/')), data)
        except Exception as e:
            logging.warning("Writing data to zip file failed: %s", e)

def buildstamp(zipname):
    """Gets the build timestamp for a zipapp archive.
    __main__.py must exist.
    """
    archive = ZipFile(zipname)
    info = archive.getinfo('__main__.py')
    archive.close()
    yy, m, dd, hh, mm = info.date_time[0:5]
    return '{0:04}-{1:02}-{2:02} {3:02}:{4:02}'.format(yy, m, dd, hh, mm)

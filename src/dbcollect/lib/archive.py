__author__    = "Bart Sjerps <bart@outrun.nl>"
__copyright__ = "Copyright 2020, Bart Sjerps"
__license__   = "GPLv3+"

import os, logging
from zipfile import ZipFile, ZIP_DEFLATED

class ZipCreateError(Exception):
    """Exception class for dealing with ZIP archives"""
    pass

class Archive():
    """A wrapper around zipfile
    Makes sure it always contains the comment which shows the magic string for dbcollect
    On close it picks up the syscollect logfile
    Files and strings are prefixed with the hostname to avoid making a mess un unzip
    """
    zip = None
    def __init__(self, path, logpath, version):
        try:
            self.prefix  = os.uname()[1]
            self.path    = path
            self.logpath = logpath
            self.zip = ZipFile(self.path,'w', ZIP_DEFLATED)
            comment = 'dbcollect version={} hostname={}'.format(version, self.prefix)
            self.zip.comment = comment.encode('utf-8')
        except Exception as e:
            raise ZipCreateError("Cannot create zipfile") # : {}".format(path))
    def __del__(self):
        if not self.zip:
            return
        try:
            if os.path.isfile(self.logpath):
                self.zip.write(self.logpath,os.path.join(self.prefix, 'dbcollect.log'))
        except OSError:
            logging.error("Storing logfile failed")
        try:
            os.unlink(self.logpath)
        except:
            logging.warning("Removing logfile failed")
        self.zip.close()
    def store(self, path, tag=None):
        if tag:
            fulltag = os.path.join(self.prefix, tag)
        else:
            fulltag = os.path.join(self.prefix, path.lstrip('/'))
        try:
            logging.debug('retrieving file {}'.format(path))
            self.zip.write(path, fulltag)
        except OSError as e:
            pass
        except IOError as e:
            pass
    def move(self, path, tag=None):
        self.store(path, tag)
        os.unlink(path)
    def writestr(self, tag, data):
        self.zip.writestr(os.path.join(self.prefix, tag), data)

def buildstamp(zipname):
    """Gets the build timestamp for a zipapp archive.
    __main__.py must exist.
    """
    with ZipFile(zipname) as archive:
        info = archive.getinfo('__main__.py')
        yy, mm, dd, hh, mm = info.date_time[0:5]
        return '{:04}-{:02}-{:02} {:02}:{:02}'.format(yy, mm, dd, hh, mm)

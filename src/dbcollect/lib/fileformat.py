"""
fileformat.py - Data file formatting for dbcollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import sys, os, io, platform, logging, json
from datetime import datetime
from collections import OrderedDict
from lib.config import versioninfo
from lib.functions import execute
from lib.user import getuser, getgroup

class JSONFile():
    """Container for a JSON file"""
    def __init__(self, cmd=None, path=None, **kwargs):
        self.info = OrderedDict()
        self.info['application']  = 'dbcollect'
        self.info['version']      = versioninfo['version']
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['machine']      = platform.machine()   # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
        self.info['system']       = platform.system()    # Linux  | SunOS | SunOS | AIX | Windows
        self.info['processor']    = platform.processor() # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['timestamp']    = datetime.now().strftime("%Y-%m-%d %H:%M")
        self.info['timestamputc'] = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        self.info.update(kwargs)
        self.errors = None
        self.data   = None
        if cmd:
            self.execute(cmd)
        elif path:
            self.readfile(path)

    def set(self, name, val):
        self.info[name] = val

    def execute(self, cmd):
        """
        Execute a command and return the output with the header.
        Also record status and errors
        """
        self.info['mediatype'] = 'command'
        self.info['format']    = 'text'
        self.info['command']   = cmd
        out, err = None, None
        try:
            out, err, rc = execute(cmd)
            self.data   = out
            self.errors = err
            self.info['status']     = 'OK'
            self.info['returncode'] = rc
        except OSError as e:
            self.info['status']     = os.strerror(e.errno)
            self.info['returncode'] = None

    def readfile(self, path):
        """
        Retrieve a flat file and return the output with the header.
        Also record status and errors
        """
        self.info['mediatype'] = 'flatfile'
        self.info['format']    = 'raw'
        self.info['path']      = path
        if not os.path.isfile(path):
            logging.debug('%s: No such file or directory', path)
            self.info['status'] = 'ERROR'
            return
        try:
            statinfo = os.stat(path)
            self.info['size']  = statinfo.st_size
            self.info['mode']  = oct(statinfo.st_mode)
            self.info['user']  = getuser(statinfo.st_uid)
            self.info['group'] = getgroup(statinfo.st_gid)
            self.info['atime'] = datetime.fromtimestamp(int(statinfo.st_atime))
            self.info['mtime'] = datetime.fromtimestamp(int(statinfo.st_mtime))
            with open(path) as f:
                self.data = f.read()
            self.info['status'] = 'OK'
        except IOError as e:
            self.info['status'] = os.strerror(e.errno)
        except Exception as e:
            self.info['status'] = 'Critical Error'
            logging.critical(e)

    def dump(self):
        """Return the data as JSON text"""
        return json.dumps(self.info, indent=2, sort_keys=True)

    def richtext(self):
        """Return the data as dbcollect RICH text"""
        buf = io.BytesIO()
        buf.write('# ---\n')
        for k, v in self.info.items():
            buf.write('# {0}: {1}\n'.format(k, v))
        if self.errors:
            buf.write('# error: {0}'.join(self.errors.splitlines()))
        buf.write('# ---\n')
        if self.data:
            buf.write(self.data)
        buf.seek(0)
        return buf.read()

"""
fileformat.py - Data file formatting for dbcollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import sys, os, io, platform, logging, json
from datetime import datetime
from collections import OrderedDict
from lib.config import versioninfo
from lib.functions import stat2time, execute
from lib.user import getuser, getgroup

class JSONFile():
    """Container for a JSON file"""
    def __init__(self, description):
        self.info = OrderedDict(application='dbcollect')
        self.info['version']      = versioninfo['version']
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['machine']      = platform.machine()   # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
        self.info['system']       = platform.system()    # Linux  | SunOS | SunOS | AIX | Windows
        self.info['processor']    = platform.processor() # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['timestamp']    = datetime.now().strftime("%Y-%m-%d %H:%M")
        self.info['timestamputc'] = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        self.info['description']  = description

    def set(self, name, val):
        self.info[name] = val

    def dump(self):
        return json.dumps(self.info, indent=2, sort_keys=True)

class Datafile():
    """Container for a file stored in the dbcollect archive.
    There is always a header with metadata - Parsable using YAML or plaintext.
    The original content starts after the second '# ---' line.
    """
    def __init__(self):
        self.buf = io.BytesIO()
        self.info = OrderedDict(application='dbcollect')
        self.info['version']      = versioninfo['version']
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['machine']      = platform.machine()   # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
        self.info['system']       = platform.system()    # Linux  | SunOS | SunOS | AIX | Windows
        self.info['processor']    = platform.processor() # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['timestamp']    = datetime.now().strftime("%Y-%m-%d %H:%M")
        self.info['timestamputc'] = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        self.info['mediatype']    = None
        self.info['format']       = None
        self.info['fields']       = None
    def write(self, s):
        if sys.version_info[0] == 2:
            self.buf.write(s)
        else:
            self.buf.write(s.encode())
    def header(self, errors=None):
        self.write('# ---\n')
        for k, v in self.info.items():
            self.write('# {0}: {1}\n'.format(k, v))
        if errors:
            for line in errors.splitlines():
                self.write('# error: {0}\n'.format(line))
        self.write('# ---\n')
    def execute(self, cmd):
        """Execute a command and return the output with the header.
        Also record status and errors"""
        self.info['mediatype'] = 'command'
        self.info['format']    = 'text'
        self.info['command']   = cmd
        out, err = None, None
        try:
            out, err, rc = execute(cmd)
            self.info['status']     = 'OK'
            self.info['returncode'] = rc
        except OSError as e:
            self.info['status']     = os.strerror(e.errno)
            self.info['returncode'] = None
            raise
        finally:
            self.header(err)
            if out:
                self.write(out)
            self.buf.seek(0)
            return self.buf.read()
    def file(self, path):
        """Retrieve a flat file and return the output with the header.
        Also record status and errors"""
        self.info['mediatype'] = 'flatfile'
        self.info['format']    = 'raw'
        self.info['path']      = path
        data = None
        if not os.path.isfile(path):
            logging.debug('%s: No such file or directory', path)
            return
        try:
            with open(path) as f:
                data = f.read()
            statinfo = os.stat(path)
            self.info['size']  = statinfo.st_size
            self.info['mode']  = oct(statinfo.st_mode)
            self.info['user']  = getuser(statinfo.st_uid)
            self.info['group'] = getgroup(statinfo.st_gid)
            self.info['atime'] = stat2time(statinfo.st_atime)
            self.info['mtime'] = stat2time(statinfo.st_mtime)
            self.info['status'] = 'OK'
        except IOError as e:
            self.info['status'] = os.strerror(e.errno)
        except Exception as e:
            self.info['status'] = 'Critical Error'
            logging.critical(e)
        finally:
            self.header()
            if data:
                self.write(data)
            self.buf.seek(0)
            return self.buf.read()

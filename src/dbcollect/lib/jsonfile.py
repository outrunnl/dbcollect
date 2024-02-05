"""
jsonfile.py - Data file formatting for dbcollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import sys, os, platform, logging, json, time
from datetime import datetime

try:
    from lib.buildinfo import buildinfo
except ImportError:
    print("Error: No buildinfo")
    sys.exit(20)

from lib.user import username, usergroup, usergroups, getuser, getgroup
from lib.config import versioninfo
from lib.functions import execute

class JSONFile():
    """
    Container for a JSONPlus file
    JSONPlus file format is simply a JSON with the data of a command or file appended
    """
    def __init__(self, cmd=None, path=None, **kwargs):
        self.info = {}
        self.info['application']  = 'dbcollect'
        self.info['version']      = versioninfo['version']
        self.info['hostname']     = platform.uname()[1]  # Hostname
        self.info['machine']      = platform.machine()   # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
        self.info['system']       = platform.system()    # Linux  | SunOS | SunOS | AIX | Windows
        self.info['processor']    = platform.processor() # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
        self.info['timestamp']    = datetime.now().strftime("%Y-%m-%d %H:%M")
        self.info['timestamputc'] = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        self.info.update(kwargs)
        self.errors = None
        self.data   = None
        if cmd:
            self.execute(cmd)
        elif path:
            self.readfile(path)
        self.info.update(kwargs)

    def meta(self):
        runinfo = {}
        runinfo['python']      = platform.python_version()
        runinfo['timezone']    = time.strftime("%Z", time.gmtime())           # The system's configured timezone
        runinfo['cmdline']     = ' '.join(sys.argv)        # Command by which we are called
        runinfo['username']    = username()                # Username (after switching from root)
        runinfo['usergroup']   = usergroup()               # Primary group
        runinfo['usergroups']  = ','.join(usergroups())    # List of groups we are a member of
        runinfo['zipname']     = os.path.realpath(__loader__.archive)
        self.info['runinfo']   = runinfo
        self.info['buildinfo'] = buildinfo

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
            self.info['status']     = 'ERROR'
            self.errors             = os.strerror(e.errno)
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
            self.info['status'] = 'Nonexistent'
            return
        try:
            statinfo = os.stat(path)
            self.info['size']  = statinfo.st_size
            self.info['mode']  = oct(statinfo.st_mode)
            self.info['user']  = getuser(statinfo.st_uid)
            self.info['group'] = getgroup(statinfo.st_gid)
            self.info['atime'] = datetime.fromtimestamp(int(statinfo.st_atime)).strftime("%Y-%m-%d %H:%M")
            self.info['mtime'] = datetime.fromtimestamp(int(statinfo.st_mtime)).strftime("%Y-%m-%d %H:%M")
            with open(path) as f:
                self.data = f.read()
            self.info['status'] = 'OK'
        except IOError as e:
            self.info['status'] = 'ERROR'
            self.errors = os.strerror(e.errno)
        except Exception as e:
            self.info['status'] = 'ERROR'
            self.info['status'] = 'Critical Error'
            logging.critical(e)

    def dbinfo(self, instance, name, path):
        """
        Create a dbinfo report
        """
        self.info['mediatype'] = 'dbinfo'
        self.info['format']    = 'sqlplus'
        self.info['script']    = name
        self.info['oracle']    = instance.meta()
        try:
            with open(path) as f:
                self.data = f.read()
            os.unlink(path)
        except Exception as e:
            self.info['status'] = 'ERROR'
            self.errors = 'Data not available'

    def dir(self, *dirs):
        self.info['directories'] = []
        for dir in dirs:
            if not os.path.isdir(dir):
                self.info['directories'].append({ 'directory': dir, 'exists': False })
                continue
            files = []
            for file in sorted(os.listdir(dir)):
                path = os.path.join(dir, file)
                if not os.path.isfile(path):
                    continue
                st = os.stat(path)
                files.append({
                    'path': path,
                    'size': st.st_size,
                    'mtime': datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M"),
                    'user': getuser(st.st_uid),
                    'group': getgroup(st.st_gid)
                })
            self.info['directories'].append({ 'directory': dir, 'files': files})

    def dump(self):
        """Return the data as JSON text"""
        return json.dumps(self.info, indent=2, sort_keys=True)

    def save(self, path):
        """Save self as jsonp file"""
        with open(path, 'w') as f:
            f.write(self.jsonp())

    def jsonp(self):
        """Return the data as JSONPlus"""
        if self.errors:
            self.info['errors'] = self.errors.splitlines()
        data = json.dumps(self.info, indent=2, sort_keys=True)
        if self.data:
            data += '\n'
            data += self.data
        return data

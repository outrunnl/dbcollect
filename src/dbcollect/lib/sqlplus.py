"""
sqlplus.py - Run SQL*Plus and other binaries in ORACLE_HOME
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, re, logging, errno
from subprocess import Popen, PIPE, STDOUT
from lib.errors import Errors, SQLPlusError, CustomException

def sqlplus(orahome, sid, connectstring, tmpdir, quiet=False, timeout=None):
    """
    Create a Popen() SQL*Plus session
    if quiet=True, redirect stdout to /dev/null.
    Note: SQL*Plus never writes to stderr.
    """
    env  = { 'ORACLE_HOME': orahome, 'ORACLE_SID': sid }
    sqlplus_bin = os.path.join(orahome, 'bin/sqlplus')
    timeout_bin = '/usr/bin/timeout'

    if connectstring:
        cmd  = [sqlplus_bin, '-S', '-L', connectstring]
    else:
        cmd  = [sqlplus_bin, '-S', '-L', '/', 'as', 'sysdba']

    if timeout is not None:
        cmd.insert(0, str(timeout))
        cmd.insert(0, timeout_bin)

    if quiet:
        stdout = open('/dev/null', 'w')
    else:
        stdout = PIPE

    try:
        if sys.version_info[0] == 2:
            proc = Popen(cmd, cwd=tmpdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=STDOUT)
        else:
            proc = Popen(cmd, cwd=tmpdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=STDOUT, encoding='utf-8')

        return proc

    except OSError as e:
        raise SQLPlusError(Errors.E019, sqlplus_bin, os.strerror(e.errno))

def get_dbsdir(orahome):
    orabasetab = os.path.join(orahome, 'install', 'orabasetab')
    try:
        with open(orabasetab) as f:
            data = f.read()

        r = re.search(r'^/.*:(.*):(.*):(.*):(.*)', data, re.M)
        orabase  = r.group(1)
        readonly = r.group(3)

        if readonly in ('Y', 'y'):
            dbsdir = os.path.join(orabase, 'dbs')

        else:
            dbsdir = os.path.join(orahome, 'dbs')

        return dbsdir

    except IOError as e:
        if e.errno == errno.ENOENT:
            logging.debug('No orabasetab found, using ORACLE_HOME/dbs')
            dbsdir = os.path.join(orahome, 'dbs')
            return dbsdir
        else:
            raise CustomException(Errors.E028, orabasetab)
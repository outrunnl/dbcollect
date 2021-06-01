__author__    = "Bart Sjerps <bart@outrun.nl>"
__copyright__ = "Copyright 2020, Bart Sjerps"
__license__   = "GPLv3+"

import os, logging, pkgutil, datetime, time, hashlib, errno
from subprocess import call, Popen, PIPE

def listdir(dir):
    """Return all files/dirs in dir, or empty list if not exists"""
    if not os.path.isdir(dir):
        return []
    return sorted(os.listdir(dir))

def makedir(dir):
    """Call mkdir but ignore if dir already exists"""
    try:
        os.mkdir(dir)
    except OSError as e:
        if e.errno == errno.EEXIST:
            pass
        else:
            raise

def getfile(*args):
    """try each file from paths until readable, try next if not exists or no access"""
    for path in args:
        try:
            with open(path) as f:
                return f.read()
        except IOError as e:
            if e.errno in [errno.ENOENT, errno.EACCES]:
                continue
            raise

def saferemove(path):
    """Delete a file only if it exists in /tmp"""
    if path.startswith('/tmp'):
        os.unlink(path)
    else:
        raise ValueError('Trying to remove file outside /tmp')

def execute(cmd, hide_errors=False, opts=None):
    """
    Run a command, and return the output of stdout. Any stderr messages will be logged.
    If the command fails (i.e. does not exists or exits with non-zero return code), logs an error
    Even if the command fails, still an empty string is returned so the program continues.
    Provide opts as an array with extra options, these will be appended w/o changes.
    """
    command = cmd.split(' ')
    if opts:
        command += opts
    env = {}
    # Setting PATH for UNIX and Linux. On AIX we also need objrepos
    env['PATH'] = '/usr/sbin:/usr/bin:/bin:/sbin'
    env['ODMDIR'] = '/etc/objrepos'
    try:
        logging.debug('Executing command: {0}'.format(cmd))
        proc = Popen(command, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdout, stderr = proc.communicate()
        if not hide_errors:
            if stderr:
                logging.error('{0}, {1}'.format(cmd, stderr))
        return stdout.rstrip('\n')
    except OSError as oe:
        if oe.errno == errno.ENOENT:
            # Command failed or does not exist
            logging.warning('executing {0}: {1}'.format(command[0], os.strerror(oe.errno)))
        else:
            logging.warning('error executing {0}: {1}'.format(command[0], os.strerror(oe.errno)))

def filedate(path):
    """Return mtime for a file"""
    return os.stat(path).st_mtime

def md5hash(path):
    """Return MD5 hash (string) for a file"""
    hash = hashlib.md5()
    if path and os.path.isfile(path):
        with open(path,'rb') as f:
            buf = f.read(8192)
            while len(buf):
                hash.update(buf)
                buf = f.read(8192)
        return hash.hexdigest()
    return None

def utcnow():
    return datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M")

def now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

def timezone():
    return time.strftime("%Z", time.gmtime())

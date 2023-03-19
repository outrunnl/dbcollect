"""
functions.py - Some functions for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, logging, pkgutil, datetime, time, errno
from subprocess import call, Popen, PIPE

def listdir(dir):
    """Return all files/dirs in dir, or empty list if not exists"""
    if not os.path.isdir(dir):
        return []
    return sorted(os.listdir(dir))

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

def execute(cmd):
    """
    Run a command, and return the output of stdout. Any stderr messages will be logged.
    If the command fails (i.e. does not exists or exits with non-zero return code), logs an error
    Even if the command fails, still an empty string is returned so the program continues.
    Provide opts as an array with extra options, these will be appended w/o changes.
    """
    command = cmd.split(' ')
    env = {}
    # Setting PATH for UNIX and Linux. On AIX we also need objrepos
    env['PATH'] = '/usr/sbin:/usr/bin:/bin:/sbin'
    env['ODMDIR'] = '/etc/objrepos'
    if sys.version_info[0] == 2:
        proc = Popen(command, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
    else:
        proc = Popen(command, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE, encoding='utf-8')
    stdout, stderr = proc.communicate()
    return (stdout, stderr, proc.returncode)

def timezone():
    return time.strftime("%Z", time.gmtime())

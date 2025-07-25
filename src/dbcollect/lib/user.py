"""
user.py - Manage DBCollect ZIP archives
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+

Switch user if the current user is root
This serves 2 purposes:
1) Safety against bugs
2) Oracle SQL*Plus must be executed as a 'sysdba' which requires an OS user
   with these permissions. Usually 'oracle'.

The primary group and other group memberships are also detected and setup.

If 'oracle' is not found, switch to 'nobody' so dbcollect will still work
safely on systems without Oracle.
"""

import os, sys, re, errno
import pwd, grp
from pkgutil import get_data
from subprocess import CalledProcessError, Popen
from lib.functions import execute

def dbuser():
    """"Find the first Oracle database owner"""
    stdout, _, _ = execute('ps -eo uid,args')
    for uid, cmd in re.findall(r'(\d+)\s+(.*)', stdout):
        r = re.match(r'ora_pmon_(\w+)', cmd)
        if r:
            user = pwd.getpwuid(int(uid)).pw_name
            return user
    return None

def switchuser(user, args):
    """Call self as a different user with the same parameters"""
    if user is None:
        user = 'oracle'
    try:
        uid = pwd.getpwnam(user).pw_uid
        home = pwd.getpwnam(user).pw_dir
    except KeyError:
        print("User {0} not available, trying 'nobody'".format(user))
        try:
            user = 'nobody'
            uid = pwd.getpwnam(user).pw_uid
            home = '/tmp'
        except KeyError:
            print("User nobody not available, giving up")
            sys.exit(20)
    gid = pwd.getpwnam(user).pw_gid
    os.setgid(gid)
    groups = [g.gr_gid for g in grp.getgrall() if user in g.gr_mem]
    groups.append(gid)
    os.setgroups(groups)
    os.setuid(uid)

    try:
        get_data('lib', 'config.py')
    except PermissionError:
        ziploc = os.path.realpath(sys.path[0])
        print('Cannot read dbcollect package {0}, exiting...'.format(ziploc))
        sys.exit(10)

    try:
        os.chdir(home)
    except OSError:
        os.chdir('/tmp')
    try:
        proc = Popen(args)
        proc.communicate()
        sys.exit(proc.returncode)

    except KeyboardInterrupt:
        print("Aborted, exiting...")
        sys.exit(10)

    except CalledProcessError as e:
        sys.exit(e.returncode)

    except OSError as e:
        if e.errno in [errno.EACCES]:
            print('%s, %s' % (e, ' '.join(args)))
    sys.exit(0)

def username():
    """Return the username for the current userid"""
    return pwd.getpwuid(os.getuid()).pw_name

def usergroup():
    """Return the primary group for the current groupid"""
    return grp.getgrgid(os.getgid()).gr_name

def usergroups():
    """Return the groups for the current user"""
    user = pwd.getpwuid(os.getuid()).pw_name
    return [g.gr_name for g in grp.getgrall() if user in g.gr_mem]

def getuser(uid):
    """Return the username for a given uid"""
    uinfo = pwd.getpwuid(uid)
    return uinfo.pw_name

def getgroup(gid):
    """Return the groupname for a given gid"""
    ginfo = grp.getgrgid(gid)
    return ginfo.gr_name

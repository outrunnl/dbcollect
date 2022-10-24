__author__    = "Bart Sjerps <bart@dirty-cache.com>"
__copyright__ = "Copyright 2020, Bart Sjerps"
__license__   = "GPLv3+"

"""
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
from subprocess import check_call, CalledProcessError
from lib.functions import execute

def dbuser():
    """"Find the first Oracle database owner"""
    stdout, stderr, rc = execute('ps -eo uid,args')
    for uid, cmd in re.findall(r'(\d+)\s+(.*)', stdout):
        r = re.match(r'ora_pmon_(\w+)', cmd)
        if r:
            sid  = r.group(1)
            user = pwd.getpwuid(int(uid)).pw_name
            return user

def switchuser(user, args):
    """Call self as a different user with the same parameters"""
    if user is None:
        user = 'oracle'
    try:
        uid = pwd.getpwnam(user).pw_uid
        home = pwd.getpwnam(user).pw_dir
    except KeyError as e:
        print("User {0} not available, trying 'nobody'".format(user))
        try:
            user = 'nobody'
            uid = pwd.getpwnam(user).pw_uid
            home = '/tmp'
        except KeyError as e:
            print("User nobody not available, giving up")
            exit(20)
    gid = pwd.getpwnam(user).pw_gid
    os.setgid(gid)
    groups = [g.gr_gid for g in grp.getgrall() if user in g.gr_mem]
    groups.append(gid)
    os.setgroups(groups)
    os.setuid(uid)
    os.chdir(home)
    try:
        check_call(args)
    except KeyboardInterrupt:
        print("Aborted, exiting...")
        exit(10)
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

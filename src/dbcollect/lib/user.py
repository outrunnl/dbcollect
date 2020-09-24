__author__    = "Bart Sjerps <bart@outrun.nl>"
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

import os
import pwd, grp

# Handle oracle not existing ('nobody'?)

def switchuser(user):
    """Checks if the user is non-root"""
    uid = os.getuid()
    if uid == 0:
        try:
            uid = pwd.getpwnam(user).pw_uid
            home = pwd.getpwnam(user).pw_dir
        except KeyError as e:
            print("User {} not available, trying 'nobody'".format(user))
            try:
                user = 'nobody'
                uid = pwd.getpwnam(user).pw_uid
                home = '/tmp'
            except KeyError as e:
                print("User 'nobody not available, giving up")
                exit(20)
        gid = pwd.getpwnam(user).pw_gid
        os.setgid(gid)
        groups = [g.gr_gid for g in grp.getgrall() if user in g.gr_mem]
        groups.append(gid)
        os.setgroups(groups)
        os.setuid(uid)
        os.chdir(home)

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

#!/usr/bin/env python
"""
dbcollect.py - Retrieve Oracle database and OS config and performance data
Copyright (c) 2020 - Bart Sjerps <bart@outrun.nl>
License: GPLv3+
"""

import os, sys, json, logging, pkgutil, platform, datetime
sys.dont_write_bytecode = True
try:
    import argparse
except:
    print("ERROR: Cannot import module 'argparse'. Please install python-argparse first:\nyum install python-argparse")
    exit(10)

from shutil import rmtree
from lib import *
from modules import *

__author__    = "Bart Sjerps <bart@outrun.nl>"
__copyright__ = "Copyright 2020, Bart Sjerps"
__license__   = "GPLv3+"
__version__   = "1.4.3"

def selfinfo():
    info = dict()
    try:
        zipname = os.path.realpath(__loader__.archive)
        if not os.access(zipname,os.R_OK):
            raise DBCollectError('User {0} has no read access to {1}'.format(username(), zipname))
        info['zipname']   = zipname
        info['ziphash']   = md5hash(zipname)
        info['builddate'] = buildstamp(zipname)
    except NameError as e:
        st = os.stat(__file__).st_mtime
        dt = datetime.datetime.fromtimestamp(st)
        info['zipname']   = None
        info['ziphash']   = None
        info['builddate'] = dt.strftime('%Y-%m-%d %H:%M')
    return info

def printversion():
    info = selfinfo()
    print ('Author:    {0}'.format(__author__))
    print ('Copyright: {0}'.format(__copyright__))
    print ('License:   {0}'.format(__license__))
    print ('Version:   {0}'.format(__version__))
    print ('Builddate: {0}'.format(info['builddate']))

def meta():
    info = dict()
    info['application']   = 'dbcollect'
    info['version']       = __version__
    info['machine']       = platform.machine()        # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
    info['system']        = platform.system()         # Linux  | SunOS | SunOS | AIX | Windows
    info['processor']     = platform.processor()      # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
    info['hostname']      = platform.uname()[1]       # Hostname
    info['python']        = platform.python_version()
    info['timestamp']     = now()                     # Current time, local timezone
    info['timestamputc']  = utcnow()                  # Current time, UTC
    info['timezone']      = timezone()                # The system's configured timezone
    info['cmdline']       = ' '.join(sys.argv)        # Command by which we are called
    info['username']      = username()                # Username (after switching from root)
    info['usergroup']     = usergroup()               # Primary group
    info['usergroups']    = ','.join(usergroups())    # List of groups we are a member of
    info.update(selfinfo())                           # Add author/version/copyright info
    return json.dumps(info,indent=2, sort_keys=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-V", "--version",   action="store_true", help="Version and copyright info")
    parser.add_argument("-D", "--debug",     action="store_true", help="Debug (Show errors)")
    parser.add_argument("-S", "--statspack", action="store_true", help="Run statspack instead of AWR")
    parser.add_argument(      "--force",     action="store_true", help="Run AWR reports even if AWR usage (license) is not detected. Dangerous!")
    parser.add_argument(      "--delete",    action="store_true", help="Delete previous zip file")
    parser.add_argument("-q", "--quiet",     action="store_true", help="Suppress output")
    parser.add_argument(      "--no-awr",    action="store_true", help="Skip AWR reports")
    parser.add_argument(      "--no-sar",    action="store_true", help="Skip SAR reports")
    parser.add_argument(      "--no-ora",    action="store_true", help="Skip all Oracle info")
    parser.add_argument(      "--no-sys",    action="store_true", help="Skip OS info")
    parser.add_argument("-o", "--output",    type=str, help="output file, default dbcollect-<hostname>.zip")
    parser.add_argument(      "--tmpdir",    type=str, default='/tmp',   help="temp dir (/tmp)")
    parser.add_argument("-u", "--user",      type=str, default='oracle', help="Run as user (default oracle)")
    parser.add_argument("-d", "--days",      type=int, default=10, help="Number of days to collect AWR data (default 10, max 999)")
    parser.add_argument(      "--offset",    type=int, default=0,  help="Number of days to shift AWR collect period, default 0, max 999")
    args = parser.parse_args()

    if args.version:
        printversion()
        return
    if args.quiet:
        sys.stdout = open('/dev/null','w')
    if args.output:
        if args.output.startswith('/'):
            zippath = os.path.splitext(args.output)[0] + '.zip'
        else:
            zippath = os.path.join(os.getcwd(),os.path.splitext(args.output)[0] + '.zip')
    else:
        zippath = (os.path.join(args.tmpdir, 'dbcollect-{0}.zip'.format(platform.uname()[1])))
    logpath = (os.path.join(args.tmpdir, 'dbcollect.log'))
    if args.delete and os.path.isfile(zippath):
        try:
            os.unlink(zippath)
        except Exception as e:
            print("Cannot remove {0}, {1}".format(zippath, e))
    switchuser(args.user)
    try:
        logsetup(logpath, debug = args.debug, quiet=args.quiet)
    except Exception as e:
        logging.fatal("Cannot create logfile: {0}".format(e))
        exit(15)
    try:
        version = 'dbcollect version {0}\n'.format(__version__)
        archive = Archive(zippath, logpath, __version__)
        logging.info('dbcollect {0} - database and system info collector'.format(__version__))
        logging.info('User is {0}'.format(username()))
        logging.info('Zip file is {0}'.format(zippath))
        archive.writestr('meta.json', meta())
        if not args.no_sys:
            syscollect.hostinfo(archive, args)
        if not args.no_ora:
            oracle.orainfo(archive, args)
        logging.info('Zip file {0} is created succesfully.'.format(zippath))
        logging.info("Finished")
    except ZipCreateError as e:
        logging.exception("{0}: {1}".format(e, zippath))
        exit(20)
    except KeyboardInterrupt:
        logging.fatal("Aborted, exiting...")
        exit(10)
    except IOError as e:
        logging.exception("IO Error {0}".format(e))
        logging.info("Aborting")
        exit(20)
    except DBCollectError as e:
        logging.exception(e)
        logging.info("Aborting")
        exit(30)
    except Exception as e:
        logging.exception("{0}, see logfile for debug info".format(e))
        logging.info("Aborting")
        exit(40)
    finally:
        if args.debug and os.path.isfile(logpath):
            with open(logpath) as logfile:
                print("\nLogfile {0}:".format(logpath))
                print(logfile.read())

if __name__ == "__main__":
    main()

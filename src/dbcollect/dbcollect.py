#!/usr/bin/env python
"""
dbcollect.py - Retrieve Oracle database and OS config and performance data
Copyright (c) 2020 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, json, logging, platform, time
from datetime import datetime

sys.dont_write_bytecode = True
try:
    import argparse
except ModuleNotFoundError:
    print("ERROR: Cannot import module 'argparse'. Please install python-argparse first:\nyum install python-argparse")
    sys.exit(10)

try:
    from lib.buildinfo import buildinfo
except ModuleNotFoundError:
    pass

if sys.version_info[0] == 2 and sys.version_info[1] < 6:
    sys.exit("Requires Python 2 (2.6 or higher, EL6)")

from lib.config import versioninfo, settings
from lib.log import logsetup
from lib.errors import DBCollectError, ZipCreateError
from lib.archive import Archive
from lib.user import switchuser, username, usergroup, usergroups, dbuser
from modules.oracle import oracle_info
from modules.syscollect import host_info
from modules.updater import update

def selfinfo():
    info = dict()
    zipname = os.path.realpath(__loader__.archive)
    if not os.access(zipname,os.R_OK):
        raise DBCollectError('User {0} has no read access to {1}'.format(username(), zipname))
    info['zipname']   = zipname
    info.update(buildinfo)
    return info

def printversion():
    info = selfinfo()
    print ('Author:    {0}'.format(versioninfo['author']))
    print ('Copyright: {0}'.format(versioninfo['copyright']))
    print ('License:   {0}'.format(versioninfo['license']))
    print ('Version:   {0}'.format(versioninfo['version']))
    print ('Builddate: {0}'.format(info['builddate']))
    print ('Buildhash: {0}'.format(info['buildhash']))

def meta():
    info = dict()
    info['application']   = 'dbcollect'
    info['version']       = versioninfo['version']
    info['machine']       = platform.machine()        # x86_64 | sun4v | 00F6035A4C00 (AIX) | AMD64 etc...
    info['system']        = platform.system()         # Linux  | SunOS | SunOS | AIX | Windows
    info['processor']     = platform.processor()      # x86_64 | i386 | sparc | powerpc | Intel64 Family ...
    info['hostname']      = platform.uname()[1]       # Hostname
    info['python']        = platform.python_version()
    info['timestamp']     = datetime.now().strftime("%Y-%m-%d %H:%M")    # Current time, local timezone
    info['timestamputc']  = datetime.utcnow().strftime("%Y-%m-%d %H:%M") # Current time, UTC
    info['timezone']      = time.strftime("%Z", time.gmtime())           # The system's configured timezone
    info['cmdline']       = ' '.join(sys.argv)        # Command by which we are called
    info['username']      = username()                # Username (after switching from root)
    info['usergroup']     = usergroup()               # Primary group
    info['usergroups']    = ','.join(usergroups())    # List of groups we are a member of
    info.update(selfinfo())                           # Add author/version/copyright info
    return json.dumps(info,indent=2, sort_keys=True)

def main():
    parser = argparse.ArgumentParser(usage='dbcollect [options]')
    parser.add_argument("-V", "--version",   action="store_true",        help="Version and copyright info")
    parser.add_argument("-D", "--debug",     action="store_true",        help="Debug (Show errors)")
    parser.add_argument(      "--update",    action="store_true",        help="Check for updates")
    parser.add_argument("-q", "--quiet",     action="store_true",        help="Suppress output")
    parser.add_argument("-o", "--overwrite", action="store_true",        help="Overwrite previous zip file")
    parser.add_argument(      "--filename",  type=str,                   help="output filename, default dbcollect-<hostname>.zip")
    parser.add_argument(      "--tempdir",   type=str, default='/tmp',   help="TEMP directory, default /tmp")
    parser.add_argument("-u", "--user",      type=str,                   help="Switch to user (if run as root)")
    parser.add_argument("-d", "--days",      type=int, default=10,       help="Number of days to collect AWR data (default 10, max 999)")
    parser.add_argument(      "--offset",    type=int, default=0,        help="Number of days to shift AWR collect period, default 0, max 999")
    parser.add_argument(      "--force-awr", action="store_true",        help="Run AWR reports even if AWR usage (license) is not detected. Dangerous!")
    parser.add_argument(      "--ignore",    action="store_true",        help="Ignore AWR reports for databases that have no previous usage")
    parser.add_argument(      "--strip",     action="store_true",        help="Strip SQL sections from AWR reports")
    parser.add_argument(      "--local",     action="store_true",        help="Generate AWRs for local instance only")
    parser.add_argument(      "--no-awr",    action="store_true",        help="Skip AWR reports")
    parser.add_argument(      "--no-sar",    action="store_true",        help="Skip SAR reports")
    parser.add_argument(      "--no-ora",    action="store_true",        help="Skip Oracle collection")
    parser.add_argument(      "--no-sys",    action="store_true",        help="Skip OS collection")
    parser.add_argument(      "--splunk",    action="store_true",        help="Generate Dell SPLUNK/LiveOptics reports")
    parser.add_argument(      "--include",   type=str,                   help="Include Oracle instances (comma separated)")
    parser.add_argument(      "--exclude",   type=str,                   help="Exclude Oracle instances (comma separated)")
    parser.add_argument(      "--tasks",     type=int,                   help="Max number of tasks (default 50%% of cpus, 0=max)")
    args = parser.parse_args()

    if args.update:
        update(versioninfo['version'])
        return
    if os.getuid() == 0:
        cmdline = sys.argv[1:]
        cmdline.insert(0, os.path.realpath(sys.argv[0]))
        if args.user:
            switchuser(args.user, cmdline)
        else:
            user = dbuser()
            switchuser(user, cmdline)
        return

    print('dbcollect {0} - collect Oracle AWR/Statspack, database and system info'.format(versioninfo['version']))
    sys.stdout.flush()
    if args.version:
        printversion()
        return
    if args.quiet:
        sys.stdout = open('/dev/null','w')
    if args.filename:
        if not args.filename.endswith('.zip'):
            args.filename += '.zip'
        zippath = os.path.join('/tmp', args.filename)
    else:
        zippath = (os.path.join('/tmp', 'dbcollect-{0}.zip'.format(platform.uname()[1])))
    logpath = settings['logpath']
    try:
        logsetup(logpath, debug = args.debug, quiet=args.quiet)
    except Exception as e:
        logging.fatal("Cannot create logfile: {0}".format(e))
        exit(15)
    try:
        archive = Archive(zippath, args.overwrite)
        logging.info('dbcollect {0} - database and system info collector'.format(versioninfo['version']))
        logging.info('Python version {0}'.format(platform.python_version()))
        logging.info('Current user is {0}'.format(username()))
        logging.info('Zip file is {0}'.format(zippath))
        archive.writestr('meta.json', meta())
        if not args.no_sys:
            host_info(archive, args)
        if not args.no_ora:
            oracle_info(archive, args)
        logging.info('Zip file {0} is created succesfully.'.format(zippath))
        logging.info("Finished")
    except ZipCreateError as e:
        logging.error("{0}: {1}".format(e, zippath))
        logging.info("Aborting")
        exit(20)
    except KeyboardInterrupt:
        logging.fatal("Aborted, exiting...")
        exit(10)
    except IOError as e:
        logging.error("{0}: {1}".format(e.filename, os.strerror(e.errno)))
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
        archive.store(logpath, 'dbcollect.log')
        os.unlink(logpath)

if __name__ == "__main__":
    print('dbcollect must run from a ZipApp package, use https://github.com/outrunnl/dbcollect/releases/latest')
    sys.exit(10)

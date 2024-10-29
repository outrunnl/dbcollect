"""
detect.py - Detect Oracle instances
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, re, logging
from datetime import datetime
from lib.errors import Errors, CustomException, ConnectionError
from lib.functions import getfile, execute
from lib.user import getuser, getgroup
from lib.sqlplus import sqlplus, get_dbsdir

def get_inventory_homes():
    """Find all existing ORACLE_HOMEs via Oracle inventory"""
    orahomes = []
    orainst  = getfile('/etc/oraInst.loc','/var/opt/oracle/oraInst.loc')
    if not orainst:
        logging.error(Errors.E016)
        return orahomes
    try:
        r = re.match(r'inventory_loc=(.*)', orainst)
        inventory_path = os.path.join(r.group(1), 'ContentsXML/inventory.xml')
        with open(inventory_path) as f:
            inventory = f.read()

        for oradir in re.findall("<HOME NAME=\"\S+\"\sLOC=\"(\S+)\"", inventory):
            logging.debug('ORACLE_HOME (inventory): %s', oradir)
            crsctl = os.path.join(oradir, 'bin', 'crsctl')
            if os.path.isfile(crsctl):
                # This is a grid home
                logging.debug('Skipping %s (is grid home)', oradir)
                continue
            orahomes.append(oradir)

    except AttributeError as e:
        logging.error(Errors.E016)

    except IOError as e:
        logging.error(Errors.E017)

    finally:
        return orahomes

def get_oratab_homes():
    """Find all existing ORACLE_HOMEs via Oracle oratab"""
    orahomes = []
    oratab   = getfile('/etc/oratab','/var/opt/oracle/oratab')
    if not oratab:
        logging.error(Errors.E018)
    else:
        for sid, oradir in re.findall(r'^(\w+):(\S+):[y|Y|n|N]', oratab, re.M):
            logging.debug('ORACLE_HOME (oratab): %s:%s', sid, oradir)
            orahomes.append(oradir)
    return orahomes

def get_orahomes(args):
    """Find all existing ORACLE_HOMEs via oratab and/or inventory"""
    dirs    = []
    if not args.no_orainv:
        dirs = get_inventory_homes()

    if not args.no_oratab:
        dirs += get_oratab_homes()
    # return only unique dirs that exist
    return [x for x in list(set(dirs)) if os.path.isdir(x)]

def get_hcfiles(orahomes):
    """
    Find hc_*.dat files in dbs directories
    This is no longer required but indicates possible instances that are not running
    """
    hclist = []
    info = {}
    for orahome in orahomes:
        dbsdir = get_dbsdir(orahome)
        logging.debug('dbsdir (%s): %s', orahome, dbsdir)
        for file in os.listdir(dbsdir):
            path = os.path.join(dbsdir, file)
            r = re.match('hc_(.*).dat', file)
            if not r:
                continue
            sid   = r.group(1)
            stat  = os.stat(path)
            owner = getuser(stat.st_uid)
            group = getgroup(stat.st_gid)
            mtime = datetime.fromtimestamp(stat.st_mtime)
            hclist.append((path, mtime, sid, orahome, owner, group))
            if not path in info:
                info[path] = { 'sid': sid, 'mtime': mtime.strftime("%Y-%m-%d %H:%M"), 'owner': owner, 'group': group, 'orahomes': []}
            info[path]['orahomes'].append(orahome)
            logging.debug('hc_dat file: %s, %s/%s, %s', path, owner, group, mtime.strftime("%Y-%m-%d %H:%M"))

    hclist.sort(key=lambda x: x[0],reverse=True)
    sids = [info[x]['sid'] for x in info]
    logging.info('Detected instances (hc_*.dat files): %s', ', '.join(sids))

def running_instances():
    """Build list of running instances by search process list for ora_pmon_<sid> processes"""

    runlist = {}
    out, _, _ = execute('ps -eo uid,gid,args')
    for uid, gid, cmd in re.findall(r'(\d+)\s+(\d+)\s+(.*)', out):
        r = re.match(r'ora_pmon_(\w+)', cmd)
        if r:
            sid = r.group(1)
            runlist[sid] = { 'uid': uid, 'gid': gid }
            logging.debug('Running: {0} ({1}/{2})'.format(sid, getuser(int(uid)), getgroup(int(gid))))
    logging.info('Running instances: %s', ','.join(runlist.keys()))
    return runlist

def get_creds(args):
    """Parse the credentials file"""
    info = {}
    try:
        with open(args.dbcreds, 'rb') as f:
            data = f.read()
            # Required on Python 3, data is <str> on Python 2
            if isinstance(data, bytes):
                data = data.decode()

        for sid, s_enabled, conn in re.findall(r'(\S+?):([YyNn]):(.*)', data, re.M):
            enabled = s_enabled in ('Y','y')
            info[sid] = { 'enabled': enabled, 'connectstring': conn }

    except IOError as e:
        logging.error(e)
        raise CustomException(Errors.E032, args.dbcreds)

    return info

def test_sql_connection(orahome, sid, connectstring):
    """Try to connect, return True on succes, False on not avaliable, raise exception otherwise"""
    proc   = sqlplus(orahome, sid, connectstring, '/tmp', timeout=2)
    out, _ = proc.communicate('WHENEVER SQLERROR EXIT SQL.SQLCODE\nSELECT status from v$instance;')
    logging.debug('{0}, {1}, sqlplus returncode={2}'.format(sid, orahome, proc.returncode))

    if proc.returncode == 124:
        # Timeout
        raise ConnectionError(Errors.E030, sid)

    if proc.returncode == 0:
        return True

    for err, msg in re.findall(r'^(ORA-\d+):(.*)', out, re.M):
        """
        find the first ORA-* error
        Known errors:
        ORA-01034: ORACLE not available
        ORA-01033: ORACLE initialization or shutdown in progress
        ORA-12528: TNS:listener: all appropriate instances are blocking new connections
        ORA-01017: invalid username/password; logon denied
        ORA-12537: TNS:connection closed
        ORA-12514: TNS:listener does not currently know of service requested in connect
        ORA-12154: TNS:could not resolve the connect identifier specified
        ORA-12541: TNS:no listener
        ORA-12543: TNS:destination host unreachable
        """

        if err == 'ORA-01034':
            # Wrong ORACLE_HOME
            return False

        if err in ('ORA-01033','ORA-12528','ORA-12537'):
            # STARTED, MOUNTED
            raise ConnectionError(Errors.E033, sid, err, msg)

        elif err in ('ORA-01017'):
            # Wrong credentials
            raise ConnectionError(Errors.E034, sid, err, msg)

        elif err in ('ORA-12154','ORA-12514','ORA-12541','ORA-12543'):
            raise ConnectionError(Errors.E036, sid, err, msg)

        raise ConnectionError(Errors.E035, sid, err, msg)

    # If no ORA-???? error is found at all - cannot happen?
    logging.debug('%s: SQL*Plus output:\n%s\n', sid, out)
    raise ConnectionError(Errors.E001, 'SQL*Plus failed without ORA-* error')

def get_instances(args):
    """Get all detected instances by trying to connect using each available ORACLE_HOME"""
    logging.info('Detecting Oracle instances')
    instances = {}
    creds     = {}
    if args.dbcreds:
        logging.info('Using credentials file, SQL*Net connections, skipping idle instance detection')
        creds = get_creds(args)
        if args.orahome:
            orahomes = [args.orahome]
        else:
            orahomes = get_oratab_homes()
    else:
        logging.info('Using local SYSDBA connections')
        orahomes  = get_orahomes(args)
        hclist    = get_hcfiles(orahomes)

    runlist = running_instances()

    # TBD - work in progress
    """
    if args.dbcreds and args.dbremote:
        for sid in creds:
            if not sid in runlist:
                runlist[sid] = { 'connectstring': creds[sid] }
    """

    for sid in runlist:
        connectstring = None
        instances[sid] = {}
        instances[sid]['enabled'] = None
        instances[sid]['running'] = True
        instances[sid]['oracle_home'] = None
        if args.dbcreds:
            try:
                connectstring = creds[sid]['connectstring']
                instances[sid]['enabled'] = creds[sid]['enabled']
            except KeyError:
                raise CustomException(Errors.E029, sid)
        else:
            instances[sid]['enabled'] = True

        if instances[sid]['enabled'] == False:
            continue
        if not orahomes:
            raise CustomException(Errors.E031)
        for orahome in orahomes:
            status = test_sql_connection(orahome, sid, connectstring)
            if status is True:
                instances[sid]['oracle_home']   = orahome
                instances[sid]['connectstring'] = connectstring
                break

    return instances

"""
detect.py - Detect Oracle instances
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, re, logging, errno
from subprocess import Popen, PIPE
from datetime import datetime, timedelta
from lib.functions import getfile, execute
from lib.user import getuser, getgroup

def orahomes():
    """Find all existing ORACLE_HOMEs via oratab and/or inventory"""
    dirs    = []
    orainst = getfile('/etc/oraInst.loc','/var/opt/oracle/oraInst.loc')
    oratab  = getfile('/etc/oratab','/var/opt/oracle/oratab')
    if not orainst:
        logging.error('oraInst.loc not found or readable')
    else:
        r = re.match(r'inventory_loc=(.*)', orainst)
        if r:
            inventory = getfile(os.path.join(r.group(1), 'ContentsXML/inventory.xml'))
            if not inventory:
                logging.error('inventory.xml not found or readable')
            else:
                for dir in re.findall("<HOME NAME=\"\S+\"\sLOC=\"(\S+)\"", inventory):
                    logging.debug('ORACLE_HOME (inventory): %s', dir)
                    dirs.append(dir)
    if not oratab:
        logging.error('oratab not found or readable')
    else:
        for dir in re.findall(r'^\w+:(\S+):[y|Y|n|N]', oratab, re.M):
            logging.debug('ORACLE_HOME (oratab): %s', dir)
            dirs.append(dir)
    # return only unique dirs that exist
    return [x for x in list(set(dirs)) if os.path.isdir(x)]

def running_instances():
    # Build list of running instances
    runlist = dict()
    out, err, rc = execute('ps -eo uid,gid,args')
    for uid, gid, cmd in re.findall(r'(\d+)\s+(\d+)\s+(.*)', out):
        r = re.match(r'ora_pmon_(\w+)', cmd)
        if r:
            sid = r.group(1)
            runlist[sid] = dict(uid=uid, gid=gid)
            logging.debug('Running: {} ({}/{})'.format(sid, getuser(int(uid)), getgroup(int(gid))))
    return runlist

def hc_files():
    # Build list of detected instances from hc_*.dat
    hclist = []
    for orahome in orahomes():
        dbsdir = os.path.join(orahome, 'dbs')
        if not os.path.isdir(dbsdir):
            logging.debug('Skipping %s (no /dbs directory)', orahome)
            continue
        try:
            for file in os.listdir(dbsdir):
                path = os.path.join(dbsdir, file)
                r = re.match('hc_(.*).dat', file)
                if not r:
                    continue
                sid   = r.group(1)
                stat  = os.stat(path)
                owner = getuser(stat.st_uid)
                mtime = datetime.fromtimestamp(stat.st_mtime)
                hclist.append((mtime, sid, orahome, owner))
                logging.debug('%s, %s, %s', path, mtime.strftime("%Y-%m-%d %H:%M"), owner)
        except OSError as e:
            # Happens if for example we can't read the dbs dir. Just ignore.
            logging.debug('{0}: {1}'.format(dir, os.strerror(e.errno)))
    # Sort by date, most recent first
    hclist.sort(key=lambda x: x[0],reverse=True)
    return hclist

def get_instances():
    """
    Get all detected instances by searching ORACLE_HOME/dbs for files named hc_<sid>.dat
    If more hc_*.dat files are detected, the one with the latest mtime will be used.
    Check if the instance is running by looking for ora_pmon_<sid> processes.
    """
    instances = dict()
    downlist  = dict()
    runlist   = running_instances()
    detected  = hc_files()
    logging.info('Detecting Oracle instances')

    # build lists of running and stopped instances
    for mtime, sid, orahome, owner in detected:
        ts = mtime.strftime("%Y-%m-%d %H:%M")
        if sid[0] in ('+','-'):
            # Skip ASM and MGMT instances
            logging.debug('Skipping instance: %s', sid)
            continue
        if not sid in instances:
            # First entry wins, most recent
            instances[sid] = {'oracle_home': orahome, 'mtime': ts}

        if sid in runlist:
            running = True
            status  = 'UP'
        else:
            running       = False
            status        = 'DOWN'
            downlist[sid] = None
        instances[sid]['running'] = running

    logging.info('Stopped instances: %s', ', '.join(downlist.keys()))
    logging.info('Running instances: %s', ', '.join(runlist.keys()))
    for sid in instances:
        logging.debug('{0}: {1}'.format(sid, instances[sid]['oracle_home']))
    return instances

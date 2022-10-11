"""
detect.py - Detect Oracle instances
Copyright (c) 2020 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, re, logging, errno
from subprocess import Popen, PIPE
from datetime import datetime, timedelta
from lib.functions import getfile, execute
from lib.user import getuser

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
                    dirs.append(dir)
    if not oratab:
        logging.error('oratab not found or readable')
    else:
        for dir in re.findall(r'^\w+:(\S+):[y|Y|n|N]', oratab, re.M):
            dirs.append(dir)
    return [x for x in list(set(dirs)) if os.path.isdir(x)]

def get_instances():
    """Get all detected instances by searching ORACLE_HOME/dbs for files named hc_<sid>.dat
    If more hc_*.dat files are detected, the one with the latest mtime will be used.
    Check if the instance is running by looking for ora_pmon_<sid> processes.
    """
    runlist  = dict()
    downlist = dict()
    info     = dict()
    detected = []
    logging.info('Detecting Oracle instances')
    # Build list of running instances
    out, err, rc = execute('ps -eo uid,gid,args')
    for uid, gid, cmd in re.findall(r'(\d+)\s+(\d+)\s+(.*)', out):
        r = re.match(r'ora_pmon_(\w+)', cmd)
        if r:
            sid = r.group(1)
            runlist[sid] = dict(uid=uid, gid=gid)
    # Build list of detected instances from hc_*.dat
    for home in orahomes():
        logging.debug('ORACLE_HOME detected: %s', home)
        dir = os.path.join(home, 'dbs')
        try:
            for f in os.listdir(dir):
                r = re.match('hc_(.*).dat', f)
                if r:
                    sid = r.group(1)
                    if sid[0] in ('+','-'):
                        continue
                    stat  = os.stat(os.path.join(dir, f))
                    owner = getuser(stat.st_uid)
                    mtime = datetime(1970, 1, 1) + timedelta(seconds=int(stat.st_mtime))
                    detected.append((mtime, sid, home, owner))
        except OSError as e:
            # Happens if for example we can't read the dbs dir. Just ignore.
            logging.debug('{0}: {1}'.format(dir, os.strerror(e.errno)))
    # Sort by date, most recent first
    detected.sort(key=lambda x: x[0],reverse=True)
    # build lists of running and stopped instances
    for mtime, sid, orahome, owner in detected:
        if sid[0] in ('+','-'):
            # Skip ASM and MGMT instances
            continue
        ts      = mtime.strftime("%Y-%m-%d %H:%M")
        if sid in runlist:
            status = 'UP'
            uid     = runlist[sid]['uid']
            user    = getuser(int(uid))
            if sid not in info:
                info[sid] = dict(orahome=orahome,uid=uid)
        else:
            status        = 'DOWN'
            user          = owner
            downlist[sid] = None
        logging.info('Instance: %s (%s), timestamp: %s, owner: %s, oracle_home: %s', sid, status, ts, user, orahome)

    logging.info('Stopped instances: %s', ', '.join(downlist.keys()))
    logging.info('Running instances: %s', ', '.join(info.keys()))
    return info

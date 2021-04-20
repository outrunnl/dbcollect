"""
oracle.py - Oracle functions for dbcollect
Copyright (c) 2020 - Bart Sjerps <bart@outrun.nl>
License: GPLv3+
"""

import os, re, pkgutil, threading, tempfile
from subprocess import Popen, call
from shutil import rmtree
from lib import *
from lib.threads import lock
from .awrstrip import awrstrip

class OracleError(Exception):
    """Exception class for dealing with SQL*Plus issues"""
    pass

def getsql(name):
    """Gets a sql script from the sql module, returns as string"""
    return pkgutil.get_data('sql',name)

def isrunning(sid):
    """Check if an instance with ORACLE_SID sid is running via the ora_pmon_<SID> process"""
    for line in execute('ps -eo user,args').splitlines():
        user, cmd = line.split()[0:2]
        if cmd == 'ora_pmon_{0}'.format(sid):
            return True
    return False

def sqlplus(sid, orahome, sql, output=False):
    """Run SQL*Plus script or command as SYSDBA. Note sql must be of type <bytes>
    Output is hidden and returned if output == False, or else sent to stdout
    """
    env = dict(ORACLE_HOME=orahome, ORACLE_SID=sid)
    sqlpluscmd = ([os.path.join(orahome, 'bin', 'sqlplus'),'-L','-S','/', 'as','sysdba'])
    if output:
        proc = Popen(sqlpluscmd, env=env, stdin=PIPE)
    else:
        proc = Popen(sqlpluscmd, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdout, stderr = proc.communicate(sql)
    if proc.returncode:
        raise OracleError('SQL*Plus error {0}:\n=====\n{1}\n====='.format(proc.returncode, stdout))
    return stdout

def sidstatus(sid, orahome):
    """Try to connect to ORACLE_SID and return the status and version
    Return status and version
    """
    env = dict(ORACLE_HOME=orahome, ORACLE_SID=sid)
    sql = "set pagesize 0 tab off colsep |\nWHENEVER SQLERROR EXIT SQL.SQLCODE\nselect status, version from v$instance;"
    sqlpluscmd = ([os.path.join(orahome, 'bin', 'sqlplus'),'-L','-S','/', 'as','sysdba'])
    proc = Popen(sqlpluscmd, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdout, stderr = proc.communicate(sql)
    if proc.returncode:
        if 'ORA-01034' in stdout:
            return 'UNAVAILABLE', ''
        else:
            logging.warning(e)
            return None, None
    status, version = [x.strip() for x in stdout.split('|')]
    return status, version

def orahomes():
    """Get all ORACLE_HOMEs via the inventory"""
    loc = getfile('/etc/oraInst.loc','/var/opt/oracle/oraInst.loc')
    if not loc:
        return
    for d in [x.split('=',1)[1] for x in loc.splitlines() if x.startswith('inventory_loc=')]:
        inventory = getfile(os.path.join(d, 'ContentsXML/inventory.xml'))
        if not inventory:
            logging.error("Cannot access Oracle inventory")
            return
        for name, ohome in re.findall("<HOME NAME=\"(\S+)\"\sLOC=\"(\S+)\"", inventory):
            if os.path.isdir(ohome):
                yield ohome

def oratabsids():
    """
    Get ORACLE_SIDs via oratab. Note that with RAC these may also be the db_unique_name
    and databases may not be listed in oratab at all so we cannot rely on this by itself.
    Yield tuples of ORACLE_SID, ORACLE_HOME, STARTUP
    """
    tab = getfile('/etc/oratab','/var/opt/oracle/oratab')
    if not tab: return
    for line in tab.splitlines():
        r = re.match('(\w+):(\S+):.*', line)
        if r:
            sid, orahome = r.groups()
            yield sid, orahome, isrunning(sid)

def oradbssids():
    """
    Get all ORACLE_SIDs by looking up $ORACLE_HOME/dbs/hc_*.dat
    Skip locations for which we don't have access for some reason
    Filter out ASM instances (starting with +) and MGMTDB (starting with -)
    This assumes Oracle always writes hc_<sid>.dat for each running instance
    Yield tuples of ORACLE_SID, ORACLE_HOME, RUNNING
    """
    for orahome in orahomes():
        dbsdir = os.path.join(orahome, 'dbs')
        try:
            for file in os.listdir(dbsdir):
                path = os.path.join(dbsdir,file)
                if os.path.isfile(path) and file.startswith('hc_'):
                    sid = re.match('hc_(.*).dat', file).group(1)
                    if sid.startswith('+'): continue
                    if sid.startswith('-'): continue
                    yield(sid, orahome, isrunning(sid))
        except OSError as e:
            logging.debug('skip {0}'.format(dbsdir))

def checkawrlicense(sid, orahome):
    """Check if AWR reports have been used before
    If not, we must prevent running due to license violations
    """
    sql = getsql('awrusage.sql')
    feature = sqlplus(sid, orahome, sql.encode('utf-8')).strip()
    try:
        count = int(feature)
        if count:
            return True
    except:
        logging.error("AWR detection failed")
    return False

def gen_reports(shared, sid, orahome):
    """Generate AWR or Statspack reports in tmpdir
    Move the reports to the archive when done
    """
    if shared.args.statspack:
        reptype = 'statspack'
        sql = getsql('gensp.sql')
        output = False
    else:
        if not checkawrlicense(sid, orahome):
            if shared.args.force:
                logging.warning("No prior AWR usage detected, continuing anyway (--force)")
            else:
                logging.error("No prior AWR usage detected, skipping AWR reports (try --force or --statspack)")
                return
        reptype = 'awr'
        sql = getsql('genawr.sql')
        output = False if shared.args.quiet else True
    try:
        tempdir = tempfile.mkdtemp(prefix = os.path.join('/tmp', '{0}-{1}'.format(reptype, sid)))
        logging.info('tempdir %s', tempdir)
        tempsql = sqlplus(sid, orahome, sql.format(shared.args.days, shared.args.offset))
        scriptpath = os.path.join(tempdir, '{0}reports.sql'.format(reptype))
        with open(scriptpath,'w') as f:
            f.write(tempsql)
        oldwd = os.getcwd()
        os.chdir(tempdir)
        logging.info('Generating {0} reports for instance {1}, days={2}, offset={3}'.format(reptype, sid, shared.args.days, shared.args.offset))
        sqlplus(sid, orahome, '@' + scriptpath, output)
        if not shared.args.no_strip:
            logging.info("Stripping AWR reports")
            for file in [os.path.join(tempdir, f) for f in os.listdir(tempdir) if f.endswith('.html')]:
                awrstrip(file, inplace=True)
        for f in listdir(tempdir):
            r = os.path.join(tempdir, f)
            with lock:
                shared.archive.move(r, 'oracle/{0}/{1}'.format(sid, f) )
        os.chdir(oldwd)
    except OracleError as e:
        logging.exception("Oracle Error %s", e)
    except OSError as e:
        logging.exception("%s", e)
    finally:
        if os.path.isdir(tempdir):
            rmtree(tempdir)

class Shared:
    """Container class for sharing between threads"""
    excluded = []
    included = []
    processed = []
    def __init__(self, args, archive):
        self.args = args
        self.archive = archive

def instance_info(shared, sid, orahome, active):
    logging.info('Processing Oracle instance %s', sid)
    args = shared.args
    archive = shared.archive
    processed = shared.processed
    status, version = sidstatus(sid, orahome)
    if status in (None,'UNAVAILABLE'):
        logging.warning("SQL*Plus login failed, continuing with next SID")
        return
    elif status not in ['STARTED','MOUNTED', 'OPEN']:
        logging.error('Skipping instance %s (cannot connect)', sid)
        return
    elif status == 'STARTED':
        logging.info('Oracle instance %s is not mounted', sid)
        sql = getsql('instance.sql')
    elif status == 'MOUNTED':
        logging.info('Oracle instance %s is mounted (not open)', sid)
        sql = getsql('database.sql')
    elif status == 'OPEN':
        sql = getsql('dbinfo.sql')
    else:
        logerror("Oracle instance %s has unknown state: %s", sid, status)
        return
    try:
        logging.info('Getting dbinfo for Oracle instance %s', sid)
        report = sqlplus(sid, orahome, sql)
        with lock:
            archive.writestr('oracle/{0}/dbinfo-{1}.txt'.format(sid,sid),report)
        if status == 'OPEN':
            if int(version.split('.')[0]) >= 12:
                sql = getsql('{0}.sql'.format('pdbinfo'))
                pdbreport = sqlplus(sid, orahome, sql)
                logging.info('Getting pdbinfo for Oracle instance %s', sid)
                with lock:
                    archive.writestr('oracle/{0}/pdbinfo-{1}.txt'.format(sid,sid),pdbreport)
            if not args.no_awr:
                gen_reports(shared, sid, orahome)
        processed.append(sid)
    except OracleError as e:
        logging.error(e)
    except Exception as e:
        logging.exception("%s", e)

def orainfo(archive, args):
    """Collect Oracle config and workload data"""
    logging.info('Collecting Oracle info')
    shared = Shared(args, archive)
    if args.exclude:
        shared.excluded = getlist(args.exclude)
    if args.include:
        shared.included = getlist(args.include)
    # Get oracle sids via oratab and scanning $ORACLE_HOME/dbs
    sids = []
    if args.no_oratab:
        logging.info('Skipping instance detection from oratab')
    else:
        sids += [x for x in oratabsids()]
    if args.no_orainv:
        logging.info('Skipping instance detection from Oracle Inventory')
    else:
        sids += [x for x in oradbssids()]
    # Dedupe list of sids
    sids = list(set(sids))

    # Start workers
    logging.info('Max threads is %d', args.threads)
    threads = list()
    for sid, orahome, active in sids:
        if shared.included:
            if sid not in shared['included']:
                logging.info('Skipping Oracle instance %s (not included)', sid)
                continue
        if sid in shared.excluded:
            logging.info('Excluding Oracle instance %s', sid)
            continue
        if not active:
            logging.info('Skipping Oracle instance %s (not running or available)', sid)
            continue
        if sid in shared.processed:
            logging.info('Skipping Oracle instance %s (already processed)', sid)
            continue
        thread = threading.Thread(target=instance_info, name='worker_' + sid, args=(shared, sid, orahome, active))
        while threading.active_count() > args.threads:
            time.sleep(1)
        threads.append(thread)
        thread.start()
    for thread in threads:
        logging.debug('waiting for %s', thread.name)
        thread.join()

"""
oracle.py - Oracle functions for dbcollect
Copyright (c) 2020 - Bart Sjerps <bart@outrun.nl>
License: GPLv3+
"""

"""
Oracle functions for dbcollect
"""

import os, re, pkgutil, tempfile
from subprocess import Popen
from shutil import rmtree
from lib import *

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
        if cmd.lower() == 'ora_pmon_%s' % sid.lower():
            return True
    return False

def sqlplus(sid, orahome, sql, output=False):
    """Run SQL*Plus script or command as SYSDBA. Note sql must be of type <bytes>
    Output is hidden and returned if output == False, or else sent to stdout
    """
    env = {}
    env['ORACLE_HOME'] = orahome
    env['ORACLE_SID'] = sid
    sqlpluscmd = ([os.path.join(orahome, 'bin', 'sqlplus'),'-L','-S','/', 'as','sysdba'])
    if output:
        proc = Popen(sqlpluscmd, env=env, stdin=PIPE)
    else:
        proc = Popen(sqlpluscmd, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdout, stderr = proc.communicate(sql)
    if proc.returncode:
        raise OracleError('SQL*Plus error {}:\n=====\n{}\n====='.format(proc.returncode, stdout))
    return stdout

def sidstatus(sid, orahome):
    """Try to connect to ORACLE_SID and return the status and version
    Return None if connect fails
    """
    sql = "set pagesize 0 tab off colsep |\nWHENEVER SQLERROR EXIT SQL.SQLCODE\nselect status, version from v$instance;"
    try:
        connect = sqlplus(sid, orahome, sql.encode('utf-8')).rstrip()
        status, version = [x.strip() for x in connect.split('|')]
    except OracleError as e:
        logging.error(e)
        return None, None
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
            logging.debug('skip {}'.format(dbsdir))

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

def gen_reports(archive, args, sid, orahome):
    """Generate AWR or Statspack reports in tmpdir
    Move the reports to the archive when done
    """
    if args.statspack:
        reptype = 'statspack'
        sql = getsql('gensp.sql')
        output = False
    else:
        if not checkawrlicense(sid, orahome):
            if args.force:
                logging.warning("No prior AWR usage detected, continuing anyway (--force)")
            else:
                logging.error("No prior AWR usage detected, skipping AWR reports (try --force or --statspack)")
                return
        reptype = 'awr'
        sql = getsql('genawr.sql')
        output = False if args.quiet else True
    try:
        tempdir = tempfile.mkdtemp(prefix = os.path.join(args.tmpdir, '{}-{}'.format(reptype, sid)))
        tempsql = sqlplus(sid, orahome, sql.format(args.days, args.offset))
        scriptpath = os.path.join(tempdir, '{}reports.sql'.format(reptype))
        with open(scriptpath,'w') as f:
            f.write(tempsql)
        oldwd = os.getcwd()
        os.chdir(tempdir)
        logging.info('Generating {} reports for instance {}, days={}, offset={}'.format(reptype, sid, args.days, args.offset))
        sqlplus(sid, orahome, '@' + scriptpath, output)
        for f in listdir(tempdir):
            r = os.path.join(tempdir, f)
            archive.move(r, '{}/{}'.format(sid, f) )
        os.chdir(oldwd)
    except OracleError as e:
        logging.exception("Oracle Error {}".format(e))
    except OSError as e:
        logging.exception("{}".format(e))
    finally:
        if os.path.isdir(tempdir):
            rmtree(tempdir)

def orainfo(archive, args):
    """Collect Oracle config and workload data"""
    logging.info('Collecting Oracle info')
    oratab = getfile('/etc/oratab','/var/opt/oracle/oratab')
    if oratab:
        archive.writestr('oratab',oratab)
    # Get oracle sids via oratab and scanning $ORACLE_HOME/dbs
    sids = [x for x in oratabsids()] + [x for x in oradbssids()]
    # Dedupe list of sids
    sids = list(set(sids))
    for sid, orahome, active in sids:
        if not active:
            logging.info('Skipping Oracle instance {} (not running or available)'.format(sid))
            continue
        logging.info('Processing Oracle instance {}'.format(sid))
        status, version = sidstatus(sid, orahome)
        if status == None:
            logging.info("SQL*Plus login failed, continuing with next SID")
            continue
        elif status not in ['STARTED','MOUNTED', 'OPEN']:
            logging.error('Skipping instance {} (cannot connect)'.format(sid))
        elif status == 'STARTED':
            logging.info('Oracle instance {} is not mounted'.format(sid))
            sql = getsql('instance.sql')
        elif status == 'MOUNTED':
            logging.info('Oracle instance {} is mounted (not open)'.format(sid))
            sql = getsql('database.sql')
        elif status == 'OPEN':
            sql = getsql('dbinfo.sql')
        else:
            logerror("Oracle instance {} has unknown state: {}".format(sid, status))
            continue
        try:
            logging.info('Getting dbinfo for Oracle instance {}'.format(sid))
            report = sqlplus(sid, orahome, sql)
            archive.writestr('{}/dbinfo-{}.txt'.format(sid,sid),report)
            if status == 'OPEN':
                if int(version.split('.')[0]) >= 12:
                    sql = getsql('{}.sql'.format('pdbinfo'))
                    pdbreport = sqlplus(sid, orahome, sql)
                    logging.info('Getting pdbinfo for Oracle instance {}'.format(sid))
                    archive.writestr('{}/pdbinfo-{}.txt'.format(sid,sid),pdbreport)
                    if not args.no_awr:
                        gen_reports(archive, args, sid, orahome)
        except OracleError as e:
            logging.error(e)

"""
oracle.py - Oracle module for dbcollect
Copyright (c) 2020 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, re, tempfile, logging, time, errno
from pkgutil import get_data
from datetime import datetime, timedelta
from multiprocessing import Process, Lock, Queue, cpu_count, active_children, current_process
from subprocess import Popen, PIPE
from shutil import rmtree
from lib.functions import getfile, listdir, makedir
from lib.log import exception_handler, DBCollectError
from .awrstrip import awrstrip

class OracleError(Exception):
    """Exception class for dealing with SQL*Plus issues"""
    pass

class Shared():
    """Container class for messages and sharing data between processes"""
    lock  = Lock()
    jobs  = Queue()
    files = Queue()
    def __init__(self, tempdir, args):
        self.args = args
        self.tempdir = tempdir
    def clearline(self):
        """Clear entire line"""
        sys.stdout.write('\033[2K')
        sys.stdout.flush()
    def status(self, str):
        """Clear entire line, write string, move cursor to left"""
        with self.lock:
            sys.stdout.write('\033[2K{0}\033[G'.format(str))
            sys.stdout.flush()
    def info(self, msg, *args, **kwargs):
        """Log info without messing up console"""
        with self.lock:
            self.clearline()
            logging.info(msg, *args, **kwargs)
    def warning(self, msg, *args, **kwargs):
        """Log warning without messing up console"""
        with self.lock:
            self.clearline()
            logging.warning(msg, *args, **kwargs)
    def error(self, msg, *args, **kwargs):
        """Log error without messing up console"""
        with self.lock:
            self.clearline()
            logging.error(msg, *args, **kwargs)

class Instance():
    """Oracle Instance with SQL*Plus and other methods"""
    def __init__(self, tempdir, oracle_home, sid):
        self.sid     = sid
        self.workdir = os.path.join(tempdir, sid)
        self.script  = os.path.join(self.workdir, 'reports.sql')
        self.sqlplus = os.path.join(oracle_home, 'bin/sqlplus')
        self.args    = (self.sqlplus,'-L','-S','/','as','sysdba')
        self.env     = dict(ORACLE_HOME=oracle_home, ORACLE_SID=self.sid)
        self.total   = 0 # number of AWR/SP reports to be generated
        makedir(self.workdir)
        if not os.path.exists(self.sqlplus):
            raise OracleError('{0} not found'.format(self.sqlplus))
    def getsql(self, name):
        """Directly get an SQL script from the Python package"""
        if sys.version_info.major == 2:
            return get_data('sql',name)
        else:
            return get_data('sql',name).decode()
    def log_error(self, s):
        """Write errors to log file"""
        data = 'Oracle error on {0}:\n---\n{1}\n---\n'.format(self.sid, s)
        with open(os.path.join(self.workdir, 'errors.log'),'a') as f:
            print(data)
            f.write(data)
    def query(self, sql):
        """Run SQL*Plus query and return the output. Log errors if they appear"""
        header   = "WHENEVER SQLERROR EXIT SQL.SQLCODE\nSET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n"
        if sys.version_info.major == 2:
            proc     = Popen(self.args, env=self.env, cwd=self.workdir, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        else:
            proc     = Popen(self.args, env=self.env, cwd=self.workdir, stdin=PIPE, stdout=PIPE, stderr=PIPE, encoding='utf-8')
        out, err = proc.communicate(header + sql)
        if proc.returncode:
            self.log_error(out + err)
            raise OracleError('SQLPlus query exited with returncode {0}, see error log'.format(proc.returncode))
        return out.strip()
    def execute(self):
        """Run SQL*Plus script, redirect to null (needed for Statspack to avoid screen mess)
        Unfortunately due to the redirect we cannot catch ORA- errors, only return code.
        Blocks until SQL*Plus is completed (intended to work in a subprocess).
        The working directory is set to allow SQL*Plus to write spool files to current directory
        """
        with open('/dev/null','w') as devnull:
            if sys.version_info.major == 2:
                proc = Popen(self.args + ('@' + self.script,), env=self.env, cwd=self.workdir, stdin=PIPE, stdout=devnull)
            else:
                proc = Popen(self.args + ('@' + self.script,), env=self.env, cwd=self.workdir, stdin=PIPE, stdout=devnull, encoding='utf-8')
            out, err = proc.communicate('exit;\n')
        if proc.returncode:
            raise OracleError('SQLPlus execute exited with returncode {0}\n'.format(proc.returncode))
    def status(self):
        """Get instance status"""
        # Check if ora_pmon_<SID> exists
        env    = dict(PATH='/usr/sbin:/usr/bin:/bin:/sbin')
        if sys.version_info.major == 2:
            proc   = Popen('ps -eo args'.split(), env=env, stdout=PIPE)
        else:
            proc   = Popen('ps -eo args'.split(), env=env, stdout=PIPE, encoding='utf-8')
        out, _ = proc.communicate()
        if not re.search(r'^ora_pmon_%s$' % self.sid, out, re.MULTILINE):
            return 'DOWN'
        # Instance is up, get status
        return self.query("select status from v$instance;")
    def dbinfo(self):
        """Collect database info"""
        status = self.status()
        major = 0
        if status == 'DOWN':
            logging.warning('Skipped %s (DOWN)', self.sid)
        elif status == 'ERROR':
            logging.error('Skipped %s (ERROR)', self.sid)
        elif status == 'STARTED':
            # Only report instance info, nothing else is available
            sql = self.getsql('instance.sql')
        elif status == 'MOUNTED':
            # Only report instance and database info, nothing else is available
            sql = self.getsql('database.sql')
        elif status == 'OPEN':
            # Get common database/instance info
            sql = self.getsql('dbinfo.sql')
            version = self.query("select version from v$instance;")
            major   = int(version.split('.')[0])
            if major >= 11:
                sql += self.getsql('dbinfo_11.sql')
        else:
            # Should never happen:
            logging.critical('Skipped %s (unknown status %s)', self.sid, status)
        if status in ('OPEN','STARTED','MOUNTED'):
            with open(os.path.join(self.workdir, 'dbinfo.txt'), 'w') as f:
                data = self.query(sql)
                f.write(data)
                f.write('\n')
            if major >= 12:
                # Get CDB/PDB info (Oracle 12 and higher)
                with open(os.path.join(self.workdir, 'pdbinfo.txt'), 'w') as f:
                    sql  = self.getsql('pdbinfo.sql')
                    data = self.query(sql)
                    f.write(data)
                    f.write('\n')
            # Handle the LiveOptics capacity scripts
            if major < 11:
                ver = '10g'
            elif major == 11:
                ver = '11g'
            elif major >= 12:
                ver = '12c'
            now = datetime.now().strftime("%Y%m%d")
            sql = self.getsql('capacity_{0}.sql'.format(ver))
            self.query(sql)
            sql = self.getsql('capacity_splunk_{0}.sql'.format(ver))
            self.query(sql)
            return True
    def has_statspack(self):
        r = self.query("select count(table_name) from all_tables where table_name = 'STATS$SNAPSHOT';")
        return int(r) == 1
    def check_awr(self):
        """Check if AWR reports have been used before
        If not, we must prevent running due to license violations (unless --force)
        """
        sql = self.getsql('awrusage.sql')
        r = self.query(sql)
        # Return true if we detected at least 1 usage of 'AWR Report'
        if r:
            return int(r) > 0
    def prepare(self, args):
        """Prepare the report generation script"""
        if not self.status() == 'OPEN':
            logging.warning('%s: Not open, skipping reports', self.sid)
            return
        sql = 'define days   = {0}\ndefine offset = {1}\n'.format(args.days, args.offset)
        if self.check_awr():
            # If we find AWR usage, use AWR
            sql += self.getsql('getawrs.sql')
            report = self.getsql('awr_report.sql')
            logging.info('{0}: AWR usage detected, generating reports '.format(self.sid))
        elif args.force_awr:
            # AWR usage not detected but --force specified, use AWR anyway with warning
            logging.warning("{0}: No prior AWR usage detected, continuing anyway (--force-awr)".format(self.sid))
            sql += self.getsql('getawrs.sql')
            report = self.getsql('awr_report.sql')
        elif self.has_statspack():
            # AWR usage not detected, statspack detected
            logging.info('{0}: No awr, Statspack detected'.format(self.sid))
            sql += self.getsql('getsps.sql')
            report = self.getsql('sp_report.sql')
        elif args.ignore:
            # AWR not detected or allowed, statspack not detected, skip
            logging.warning("Skipping {0}: No prior AWR usage or Statspack detected (--ignore)".format(self.sid))
        else:
            # AWR not detected or allowed, statspack not detected, give up
            raise DBCollectError("No AWR or Statspack detected for {0} (try --force-awr or --ignore)".format(self.sid))
        # Get list of report parameters
        out = self.query(sql)
        lines = out.splitlines()
        self.total = len(lines)
        # Create the script
        with open(self.script,'w') as f:
            f.write("WHENEVER SQLERROR EXIT SQL.SQLCODE\n")
            f.write("set echo off head off feed off trims on lines 32767 pages 50000\n")
            f.write("alter session set nls_date_language=american;\n")
            for i, line in enumerate(lines):
                dbid, inst, beginsnap, endsnap, bts, ts = line.split(',')
                f.write(report.format(beginsnap=beginsnap, endsnap=endsnap, sid=self.sid, inst=inst, timestamp=ts, dbid=dbid))

@exception_handler
def worker(shared):
    """The worker subprocess
    Picks jobs (instances) from the queue until empty and calls SQL*Plus to generate
    the reports.
    When each job is done, scan the workdir and puts the generated files on the file queue.
    """
    proc = current_process()
    logging.debug('started worker with name %s, pid %s', proc.name, proc.pid)
    while not shared.jobs.empty():
        with shared.lock:
            # Get a job, with timeout so it raises Empty if there's a race condition
            instance = shared.jobs.get(True, 10)
        shared.info('processing instance %s', instance.sid)
        # Run execute but keep processing if it fails
        try:
            instance.execute()
        except OracleError as e:
            shared.error('(%s) %s Oracle error: %s', proc.name, instance.sid, e)
        except Exception as e:
            shared.error('(%s) %s Error: %s', proc.name, instance.sid, e)
        finally:
            # Pickup the files and put them on the file queue
            for file in listdir(instance.workdir):
                path = os.path.join(instance.workdir, file)
                if os.path.isfile(path):
                    shared.files.put((path, 'oracle/{0}/{1}'.format(instance.sid, file)))
    logging.debug('ended worker with name %s, pid %s', proc.name, proc.pid)

def oracle_info(archive, args):
    """Collect Oracle config and workload data"""
    logging.info('Collecting Oracle info')
    tempdir  = tempfile.mkdtemp(prefix = os.path.join('/tmp', 'dbcollect'))
    # Default use maximum of 25% of available cpus
    maxtasks = args.tasks if args.tasks else cpu_count()/4
    workers  = []                    # Array holding the worker processes
    shared   = Shared(tempdir, args) # Shared data between processes
    msg      = ''                    # Status update text
    reports_total = 0                # Total reports to be generated
    reports_arch  = 0                # Reports already archived to ZIP
    prev          = 0                # Previous value
    # Detect all Oracle instances on the machine
    instance_list = get_instances(tempdir, args)
    try:
        # Fill the jobs queue
        for instance in instance_list:
            # Get info, prepare the reports script and put on job queue
            try:
                if instance.dbinfo():
                    instance.prepare(args)
                    reports_total += instance.total
                    shared.jobs.put(instance)
            except OracleError as e:
                logging.error(e)
        # start workers - min 1, no more than available jobs
        if not args.no_awr:
            num_workers = max(1, min(maxtasks, shared.jobs.qsize()))
            logging.info('Generating Oracle AWR/Statspack reports, with %d workers', num_workers)
            for i in range(num_workers):
                proc = Process(target=worker, name='worker {0}'.format(i), args=(shared, ))
                proc.start()
                workers.append(proc)
            # loop until all workers are done and all files processed
            starttime = datetime.now()
            while any([x.is_alive() for x in workers]) or not shared.files.empty():
                time.sleep(0.1)
                # Move files from file queue into archive and keep track of counts
                while not shared.files.empty():
                    file, tag = shared.files.get()
                    if file.endswith('.html'):
                        reports_arch += 1
                        if shared.args.strip:
                            # Strip AWR reports from SQL text
                            logging.info("Stripping AWR report %s", file)
                            awrstrip(file, inplace=True)
                    if 'statspack' in file:
                        reports_arch += 1
                    archive.move(file, tag)
                # Report progress
                reports_found = 0
                for root, dirs, files in os.walk(tempdir):
                    # Count AWR and statspack files in tempdir
                    for file in files:
                        if file.endswith('.html') or 'statspack' in file:
                            reports_found += 1
                # If number found changed, recalc stats and update status message
                if reports_found != prev:
                    reports_done = reports_arch + reports_found
                    remaining    = reports_total - reports_done
                    if not reports_done == 0:
                        pct_done  = float(reports_done) / reports_total
                        elapsed   = datetime.now() - starttime
                        eta       = remaining * elapsed / reports_done
                        eta_t     = timedelta(seconds=eta.seconds)
                        elapsed_t = timedelta(seconds=elapsed.seconds)
                        prev      = reports_found
                        msg = 'report {0} of {1} ({2:.1%} done), elapsed: {3}, remaining: {4}'.format(
                            reports_done, reports_total, pct_done, elapsed_t, eta_t)
                        shared.status(msg)
            for proc in workers:
                proc.join()
                if proc.exitcode:
                    shared.error('Thread %s ended with rc=%d', proc.name, proc.exitcode)
            shared.info('Generating Oracle AWR/Statspack reports completed')
        else:
            shared.info('Skipping Oracle AWR/Statspack reports')
    except KeyboardInterrupt as e:
        # Needed because we need a finally section
        raise
    finally:
        # Write the last known status
        if(msg):
            print(msg)

        # Make sure subprocesses are killed
        for proc in workers:
            proc.terminate()
        # Pick up remaining files
        for root, dirs, files in os.walk(tempdir):
            for f in files:
                path = os.path.join(root, f)
                tag = '/'.join(path.rsplit('/',2)[1:])
                archive.move(path, tag)
        # Cleanup our junk
        if os.path.isdir(tempdir):
            rmtree(tempdir)

def get_instances(workdir, args):
    """Get all ORACLE_SIDs either via oratab or oraInventory"""
    orahomes = []
    orainst = getfile('/etc/oraInst.loc','/var/opt/oracle/oraInst.loc')
    oratab  = getfile('/etc/oratab','/var/opt/oracle/oratab')
    # get a list of ORACLE_HOMEs via inventory
    if not orainst:
        logging.error('oraInst.loc not found or readable')
    else:
        r = re.match(r'inventory_loc=(.*)', orainst)
        if r:
            inventory = getfile(os.path.join(r.group(1),'ContentsXML/inventory.xml'))
            if not inventory:
                logging.error('inventory.xml not found or readable')
            else:
                for home_name, oracle_home in re.findall("<HOME NAME=\"(\S+)\"\sLOC=\"(\S+)\"", inventory):
                    if os.path.isdir(oracle_home):
                        orahomes.append(oracle_home)
    # add list of ORACLE_HOMEs from oratab
    if not oratab:
        logging.error('oratab not found or readable')
    else:
        for line in oratab.splitlines():
            r = re.match('(\w+):(\S+):.*', line)
            if r:
                oracle_home = r.group(2)
                if os.path.isdir(oracle_home):
                    orahomes.append(oracle_home)
    """Search oracle_home/dbs dirs for hc_*.dat files and get the instance names.
    By looking for hc_<sid> files in each ORACLE_HOME/dbs dir we should find all running
    Oracle instances (and possibly some false positives which will be filtered later)
    We also exclude any ''--exclude'd instances. If --include is specified, we only process
    those.
    """
    for oracle_home in set(orahomes):
        dbsdir = os.path.join(oracle_home, 'dbs')
        try:
            for file in os.listdir(dbsdir):
                path = os.path.join(dbsdir,file)
                if os.path.isfile(path) and file.startswith('hc_'):
                    sid = re.match('hc_(.*).dat', file).group(1)
                    if sid.startswith('+') or sid.startswith('-'):
                        # Skip ASM (+) and MGMT (-) instances
                        continue
                    logging.info('Found instance %s on %s', sid, oracle_home)
                    if args.include:
                        included = args.include.split(',')
                        if not sid in included:
                            logging.info('%s not included, skipping...', sid)
                            continue
                    if args.exclude:
                        excluded = args.exclude.split(',')
                        if sid in excluded:
                            logging.info('%s is excluded, skipping...', sid)
                            continue
                    try:
                        instance = Instance(workdir, oracle_home, sid)
                        yield instance
                    except Exception as e:
                        # We ignore any instance that raises exceptions but log them
                        logging.exception('Skipping %s: %s', sid, e)
        except OSError as e:
            # Happens if for example we can't read the dbs dir. Just ignore.
            logging.debug('skip {0}'.format(dbsdir))

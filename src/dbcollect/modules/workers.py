"""
workers.py - Multiprocessing classes for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, time, tempfile, logging
from shutil import rmtree

from multiprocessing import Event, Queue, cpu_count
from multiprocessing.queues import Full

from lib.functions import getscript
from lib.config import dbinfo_config
from lib.jsonfile import JSONFile
from lib.log import exception_handler
from lib.errors import DBCollectError

class Shared():
    """Container class for messages and sharing data between processes"""
    def __init__(self, args, instance, tempdir):
        self.args     = args
        self.instance = instance
        self.tempdir  = tempdir
        self.jobs     = Queue(60)
        self.done     = Event()

    @property
    def tasks(self):
        if self.args.tasks is not None:
            # Default use maximum of 50% of available cpus
            tasks = self.args.tasks
            if tasks == 0:
                return cpu_count()
            tasks = max(1, self.args.tasks)
            tasks = min(tasks, cpu_count())
            return tasks
        return max(1, cpu_count()//2)

class Tempdir():
    """Temp directory class with subdirs, which cleans up the tempdir when it gets deleted"""
    def __init__(self, args):
        self.tempdir = tempfile.mkdtemp(prefix = os.path.join(args.tempdir, 'dbcollect_'))
        for subdir in ('lock','dbinfo','awr','splunk'):
            os.mkdir(os.path.join(self.tempdir, subdir))

    def __del__(self):
        rmtree(self.tempdir)

class Session():
    """SQL*Plus worker session"""
    def __init__(self, shared):
        self.tempdir  = shared.tempdir
        self.instance = shared.instance
        self.args     = shared.args
        self.proc     = self.instance.sqlplus(quiet=True)
        self.sid      = self.instance.sid
        self.ping     = time.time()
        self.status   = os.path.join(self.tempdir, 'lock', "sqlplus_lock_{0}".format(self.proc.pid))
        self.proc.stdin.write("SET tab off feedback off verify off heading off lines 32767 pages 0 trims on\n")
        self.proc.stdin.write("alter session set nls_date_language=american;\n")

    def __del__(self):
        self.proc.communicate('exit;\n')

    def submit(self, c):
        if self.proc.poll() is not None:
            self.proc = self.instance.sqlplus(quiet=True)

        # create a lockfile
        with open(self.status, 'w') as f:
            f.write(c)
        # Send query to SQL*Plus
        self.proc.stdin.write(c)
        # Tell SQL*Plus to remove lockfile once task is done
        self.proc.stdin.write("HOST rm -f {status}\n".format(status=self.status))

    def runscript(self, script, spool=None, header=None):
        query = ''
        if spool:
            query  = 'SPOOL {0}\n'.format(spool)
        if header:
            query += getscript('dbinfo/header.sql')
        query += getscript(script)
        if spool:
            query += '\nSPOOL OFF\n'
        tstart = time.time()
        elapsed = None
        status  = None

        self.submit(query)
        while not self.ready:
            rc = self.proc.poll()
            elapsed = time.time() - tstart
            if rc is not None:
                status = 'Terminated'
                logging.error("{0}: Terminated (rc={1}) running dbinfo script {2}".format(self.sid, rc, script))
                break
            if time.time() - tstart > self.args.timeout*60:
                logging.error("{0}: Timeout ({1} seconds) running dbinfo script {2}".format(self.sid, round(elapsed), script))
                status = 'Timeout'
                self.proc.terminate()
                break
            time.sleep(0.01)
        elapsed = round(time.time() - tstart,2)
        if self.ready:
            status = 'OK'

        return elapsed, status

    def genscripts(self):
        if self.instance.status == 'STARTED':
            yield 'instance.sql'
            return
        sections = ['basic']
        if self.instance.status not in ('STARTED','MOUNTED'):
            if self.instance.version == 11:
                sections += ['common', 'oracle11']
            elif self.instance.version > 11:
                sections += ['common', 'oracle12']

        for section in sections:
            for scriptname in dbinfo_config[section]:
                yield scriptname

    def dbinfo(self):
        logging.info('{0}: Running opatch lspatches'.format(self.sid))

        lspatches  = '{0} lspatches'.format(os.path.join(self.instance.orahome, 'OPatch/opatch'))
        inventory_info = JSONFile()
        inventory_info.execute(lspatches)
        inventory_info.save(os.path.join(self.tempdir, 'dbinfo', '{0}_patches.jsonp'.format(self.sid)))

        logging.info('{0}: Running dbinfo scripts'.format(self.sid))
        for scriptname in self.genscripts():
            logging.debug('{0}: Running dbinfo script {1}'.format(self.sid, scriptname))
            scriptpath = 'dbinfo/{0}'.format(scriptname)
            savepath   = '{0}/{1}_{2}'.format(self.tempdir, self.sid, scriptname.replace('.sql','.txt'))
            filename   = '{0}_{1}.jsonp'.format(self.sid, os.path.splitext(scriptname)[0])

            elapsed, status = self.runscript(scriptpath, savepath, header='common/header.sql')
            jfile = JSONFile(elapsed=elapsed, status=status)
            jfile.dbinfo(self.instance, scriptname, savepath)
            jfile.save(os.path.join(self.tempdir, 'dbinfo', filename))

        if self.args.splunk:
            if self.instance.status in ('STARTED','MOUNTED'):
                return
            logging.info('{0}: Running splunk scripts'.format(self.sid))
            if self.instance.version == 11:
                section = 'splunk_11'
            else:
                section = 'splunk_12'
            for scriptname in dbinfo_config[section]:
                logging.debug('{0}: Running splunk script {1}'.format(self.sid, scriptname))
                scriptpath = 'splunk/{0}'.format(scriptname)
                elapsed, status = self.runscript(scriptpath, header='splunk/splunk_header.sql')

            for f in os.listdir(self.tempdir):
                path    = os.path.join(self.tempdir, f)
                newpath = os.path.join(self.tempdir, 'splunk', f)
                if os.path.isdir(path):
                    continue
                if f.endswith('.dsk') or f.startswith('capacity_'):
                    os.rename(path, newpath)

    @property
    def ready(self):
        return not os.path.exists(self.status)

    @property
    def runtime(self):
        return round(time.time() - self.ping, 2)

def info_processor(shared):
    """info processor - Runs the dbinfo scripts"""
    session = Session(shared)
    session.dbinfo()

    logging.info('%s: DBInfo processor finished, elapsed time %s seconds', shared.instance.sid, session.runtime)

@exception_handler
def job_generator(shared):
    """Producer - Submits AWR/SP jobs to the job queue"""
    try:
        args   = shared.args
        for job in shared.instance.jobs:
            shared.jobs.put(job, timeout=args.timeout*60)
    except Full:
        logging.error('%s: Generator timeout (queue full)', shared.instance.sid)
        sys.exit(11)
    except Exception as e:
        logging.exception(e)
        sys.exit(20)
    finally:
        # Set the done flag even if failed
        shared.done.set()

@exception_handler
def job_processor(shared):
    """
    Worker process that handles SQL*Plus subprocesses
    Starts a range of SQL*Plus sessions, then submits a job from the job queue in the first available session
    """
    sessions = [Session(shared) for x in range(shared.tasks)]
    ping     = time.time()

    logging.info('%s: Started %s SQLPlus sessions', shared.instance.sid, len(sessions))

    while True:
        time.sleep(0.1)
        if (time.time() - ping) > shared.args.timeout*60:
            raise DBCollectError('Job processor timeout ({0})'.format(shared.instance.sid))
        if shared.jobs.empty():
            # Break the loop if job producer is done AND queue is empty
            if shared.done.is_set():
                break
            continue

        # Find an available session in which we can submit the job
        for session in sessions:
            if not session.ready:
                continue
            job = shared.jobs.get(timeout=10)
            session.submit(job.query)
            ping = time.time()
            break

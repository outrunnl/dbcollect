"""
workers.py - Multiprocessing classes for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, time, tempfile, logging
from shutil import rmtree

from multiprocessing import Event, Queue, cpu_count
from multiprocessing.queues import Empty, Full

from lib.functions import getscript
from lib.config import settings
from lib.log import exception_handler
from lib.errors import *

class Shared():
    """Container class for messages and sharing data between processes"""
    def __init__(self, args, instance, tempdir):
        self.args     = args
        self.instance = instance
        self.tempdir  = tempdir
        self.jobs     = Queue(10)
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
        else:
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
    def __init__(self, tempdir, instance):
        self.tempdir  = tempdir
        self.instance = instance
        self.proc     = instance.sqlplus(quiet=True)
        self.sid      = instance.sid
        self.ping     = time.time()
        self.status   = os.path.join(tempdir, 'lock', "sqlplus_lock_{0}".format(self.proc.pid))
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

    def run(self, *args, **kwargs):
        q = ''
        header  = kwargs.get('header')
        name    = kwargs.get('name')
        nospool = kwargs.get('nospool', False)
        if not nospool:
            q += 'SPOOL {0}/{1}_{2}.txt\n'.format(self.tempdir, self.sid, name or args[0])
        for report in args:
            q += getscript(report + '.sql')
        q += '\nSPOOL OFF\n'
        self.submit(q)
        while not self.ready:
            time.sleep(0.1)

    @property
    def ready(self):
        return not os.path.exists(self.status)

    @property    
    def runtime(self):
        return round(time.time() - self.ping)
    
@exception_handler
def job_generator(shared):
    """Producer - Submits AWR/SP jobs to the job queue"""
    try:
        args   = shared.args
        sid    = shared.instance.sid
        for job in shared.instance.jobs:
            shared.jobs.put(job, timeout=args.timeout*60)
    except Full:
        logging.error('%s: Generator timeout (queue full)', sid)
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

    instance = shared.instance
    sessions = [Session(shared.tempdir, instance) for x in range(shared.tasks)]
    ping     = time.time()

    logging.info('%s: Started %s SQLPlus sessions', instance.sid, len(sessions))

    while True:
        time.sleep(0.1)
        if (time.time() - ping) > shared.args.timeout*60:
            raise TimeoutError('Job processor timeout (%s)', shared.instance.sid)
        if shared.jobs.empty():
            # Break the loop if job producer is done AND queue is empty
            if shared.done.is_set():
                break
            continue

        # Find an available session in which we can submit the job
        for session in sessions:
            if not session.ready:
                continue
            job = shared.jobs.get(timeout=60)
            session.submit(job.query)
            ping = time.time()
            break

@exception_handler
def info_processor(shared):
    """info processor - Runs the dbinfo scripts"""
    instance = shared.instance
    session  = Session(shared.tempdir, instance)

    if instance.status == 'STARTED':
        session.run('instance')
    elif instance.status == 'MOUNTED':
        session.run('database')
    if instance.status == 'OPEN':
        if instance.version < 11:
            session.run('dbinfo')

        elif instance.version >= 11:
            session.run('dbinfo','dbinfo_11')

        if instance.version >= 12:
            session.run('pdbinfo')

    for f in os.listdir(shared.tempdir):
        path = os.path.join(shared.tempdir, f)
        newp = os.path.join(shared.tempdir, 'dbinfo', f)
        if not os.path.isfile(path):
            continue
        if f.endswith('txt'):
            os.rename(path, newp)

    if instance.status == 'OPEN':
        if shared.args.splunk:
            header = "set colsep ' '\nset timing off\nalter session set nls_date_format='YYYY-MM-DD';\n"
            if instance.version < 11:
                ext = '10g'
            elif instance.version == 11:
                ext = '11g'
            elif instance.version > 11:
                ext = '12c'

            session.run('capacity_splunk_{0}'.format(ext), header=header, nospool=True)
            session.run('capacity_{0}'.format(ext), header=header, nospool=True)

            for f in os.listdir(shared.tempdir):
                if f.startswith('capacity_') or f.endswith('.dsk'):
                    path = os.path.join(shared.tempdir, f)
                    newp = os.path.join(shared.tempdir, 'splunk', f)
                    os.rename(path, newp)

    logging.info('%s: Info processor elapsed time %s seconds', instance.sid, session.runtime)

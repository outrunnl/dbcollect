"""
workers.py - Multiprocessing classes for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, time, tempfile, logging

from multiprocessing import Process, Event, Queue, cpu_count
from multiprocessing.queues import Empty, Full
from shutil import rmtree

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
        os.mkdir(os.path.join(self.tempdir, 'reports'))
        os.mkdir(os.path.join(self.tempdir, 'awr'))

    def __del__(self):
        rmtree(self.tempdir)

class Session():
    """SQL*Plus worker session"""
    def __init__(self, tempdir, instance):
        self.proc   = instance.sqlplus(quiet=True)
        self.status = os.path.join(tempdir, "sqlplus_lock_{0}".format(self.proc.pid))
        self.proc.stdin.write("SET tab off feedback off verify off heading off lines 32767 pages 0 trims on\n")
        self.proc.stdin.write("alter session set nls_date_language=american;\n")

    def __del__(self):
        self.proc.communicate('exit;\n')

    def submit(self, c):
        # create a lockfile
        with open(self.status, 'w') as f:
            f.write(c)
        # Send query to SQL*Plus
        self.proc.stdin.write(c)
        # Tell SQL*Plus to remove lockfile once task is done
        self.proc.stdin.write("HOST rm -f {status}\n".format(status=self.status))

    @property
    def ready(self):
        if os.path.exists(self.status):
            return False
        return True

@exception_handler
def job_generator(shared):
    """Producer - Runs the dbinfo scripts, then submits jobs to the job queue"""
    try:
        args   = shared.args
        sid    = shared.instance.sid
        shared.instance.info(args)
        for job in shared.instance.jobs:
            shared.jobs.put(job, timeout=args.timeout*60)
        logging.debug('Generator done')
    except Full:
        logging.error('Generator timeout (queue full)')
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

    logging.info('Started {0} SQLPlus sessions for instance {1}'.format(len(sessions), instance.sid))

    while True:
        time.sleep(0.1)
        if (time.time() - ping) > shared.args.timeout*60:
            raise TimeoutError('Job processor timeout')
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

    logging.debug('Job processor done')

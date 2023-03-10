import os, sys, time, tempfile, logging

from multiprocessing import Process, Lock, Event, Queue, cpu_count, active_children, current_process
from multiprocessing.queues import Empty, Full
from shutil import rmtree

from lib.log import exception_handler
from lib.errors import *

class Shared():
    def __init__(self, args, instance, tempdir):
        self.args     = args
        self.instance = instance
        self.tempdir  = tempdir
        self.jobs     = Queue(10)
        self.done     = Event()

class Tempdir():
    def __init__(self, args):
        self.tempdir = tempfile.mkdtemp(prefix = os.path.join(args.tempdir, 'dbcollect_'))
        os.mkdir(os.path.join(self.tempdir, 'reports'))
        os.mkdir(os.path.join(self.tempdir, 'awr'))

    def __del__(self):
        rmtree(self.tempdir)

@exception_handler
def producer(shared):
    args   = shared.args
    sid    = shared.instance.sid
    shared.instance.info(args)
    for job in shared.instance.jobs:
        shared.jobs.put(job, timeout=10)
    shared.done.set()
    logging.info('Producer done')

class Session():
    def __init__(self, tempdir, instance):
        self.proc   = instance.sqlplus(quiet=True)
        self.status = os.path.join(tempdir, "sqlplus_{0}".format(self.proc.pid))
        self.proc.stdin.write("SET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n")

    def __del__(self):
        self.proc.communicate('exit;\n')

    def submit(self, c):
        with open(self.status, 'wb') as f:
            pass
        self.proc.stdin.write(c)
        self.proc.stdin.write("HOST rm -f {status}\n".format(status=self.status))

    @property
    def ready(self):
        if os.path.exists(self.status):
            return False
        return True


@exception_handler
def worker(shared):
    # Default use maximum of 25% of available cpus
    maxtasks = shared.args.tasks if shared.args.tasks else cpu_count()/4
    instance = shared.instance
    sessions = [Session(shared.tempdir, instance) for x in range(maxtasks)]

    logging.info('Started {0} SQLPlus sessions for instance {1}'.format(len(sessions), instance.sid))

    while True:
        time.sleep(0.1)
        if shared.jobs.empty():
            if shared.done.is_set():
                break
            continue

        for n in range(maxtasks):
            if not sessions[n].ready:
                continue
            try:
                job = shared.jobs.get(timeout=60)
                sessions[n].submit(job.query)
            except Empty:
                raise TimeoutError('Worker timeout')
            break
    logging.info('Worker done')

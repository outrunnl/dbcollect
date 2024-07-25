"""
multiproc.py - Multiprocessing classes for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, tempfile
from shutil import rmtree
from multiprocessing import Event, Queue, cpu_count

class Tempdir():
    """Temp directory class with subdirs, which cleans up the tempdir when it gets deleted"""
    def __init__(self, args):
        self.tempdir = tempfile.mkdtemp(prefix = os.path.join(args.tempdir, 'dbcollect_'))
        for subdir in ('lock','dbinfo','awr','splunk','log'):
            os.mkdir(os.path.join(self.tempdir, subdir))

    def __del__(self):
        rmtree(self.tempdir)

class Shared():
    """Container class for messages and sharing data between processes"""
    def __init__(self, args, instances, tempdir):
        self.args      = args
        self.instances = instances
        self.tempdir   = tempdir
        self.jobs      = Queue(60)
        self.done      = Event()

    @property
    def tasks(self):
        """Return the calculated number of tasks (workers)"""
        if self.args.tasks is not None:
            # Default use maximum of 50% of available cpus
            tasks = self.args.tasks
            if tasks == 0:
                return cpu_count()
            tasks = max(1, self.args.tasks)
            tasks = min(tasks, cpu_count())
            return tasks
        return max(1, min(8,cpu_count()//2))

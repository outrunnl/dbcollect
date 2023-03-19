"""
oracle.py - Oracle functions for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, re, tempfile, logging, time
from datetime import timedelta

from lib.errors import *
from lib.detect import get_instances
from .awrstrip import awrstrip
from .instance import Instance
from .workers import *

def oracle_info(archive, args):
    """Collect Oracle config and workload data"""
    logging.info('Collecting Oracle info')
    td = Tempdir(args)
    tempdir    = td.tempdir
    instances  = []
    total_jobs = 0
    done_jobs  = 0

    excluded = args.exclude.split(',') if args.exclude else []
    included = args.include.split(',') if args.include else []
    for sid, orahome in get_instances():
        if sid in excluded:
            logging.info('%s is excluded, skipping...', sid)
        elif included and not sid in included:
            logging.info('%s not included, skipping...', sid)
        else:
            instance    = Instance(tempdir, sid, orahome)
            num_jobs    = instance.get_jobs(args)
            total_jobs += num_jobs
            logging.info('{0}: {1} reports'.format(sid, num_jobs))
            instances.append(instance)

    msg = 'No reports'
    starttime = time.time()
    for instance in instances:
        shared = Shared(args, instance, tempdir)
        repdir = os.path.join(tempdir, 'reports')
        awrdir = os.path.join(tempdir, 'awr')
        generator = Process(target=job_generator, name='Generator', args=(shared,))
        processor = Process(target=job_processor, name='Processor', args=(shared,))
        processor.start()
        generator.start()
        while True:
            time.sleep(0.1)

            for filename in os.listdir(repdir):
                path = os.path.join(repdir, filename)
                archive.store(path, 'oracle/{0}/'.format(instance.sid) + filename)
                os.unlink(path)

            filelist = os.listdir(awrdir)
            if not filelist and not processor.is_alive():
                break
            for filename in filelist:
                path = os.path.join(awrdir, filename)
                if args.strip and filename.endswith('.html'):
                    awrstrip(path, inplace=True)
                    logging.debug('Stripped SQL code from {0}'.format(filename))
                archive.store(path, 'oracle/{0}/'.format(instance.sid) + filename)
                os.unlink(path)
                done_jobs += 1
                pct_done   = float(done_jobs)/total_jobs
                elapsed    = time.time() - starttime
                rps        = done_jobs/elapsed
                eta        = (total_jobs - done_jobs)*elapsed/done_jobs
                elapsed_s  = timedelta(seconds=round(elapsed))
                eta_s      = timedelta(seconds=round(eta))
                msg = 'Report {0} of {1} ({2:.1%} done), elapsed: {3}, remaining: {4}, reports/s: {5:.2f}'.format(
                        done_jobs, total_jobs, pct_done, elapsed_s, eta_s, rps)
                if args.quiet:
                    pass
                elif args.debug:
                    print(msg)
                else:
                    sys.stdout.write('\033[2K{0}\033[G'.format(msg))
                    sys.stdout.flush()

        generator.join()
        processor.join()
        sys.stdout.write('\033[2K')
        sys.stdout.flush()

        if generator.exitcode:
            raise CustomException('Job generator failed, rc={0}'.format(proc_p.exitcode))
        if processor.exitcode:
            raise CustomException('Job processor failed, rc={0}'.format(proc_w.exitcode))

    logging.info(msg)

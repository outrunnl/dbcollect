"""
oracle.py - Oracle functions for DBCollect
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, logging, time
from datetime import timedelta
from multiprocessing import Process

from lib.errors import Errors, CustomException
from lib.detect import get_instances
from lib.multiproc import Shared, Tempdir
from .awrstrip import awrstrip
from .instance import Instance
from .workers import job_generator, job_processor, info_processor

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
    inst_info = get_instances(args)

    for sid in inst_info:
        if sid in excluded:
            logging.info('%s is excluded, skipping...', sid)
        elif included and not sid in included:
            logging.info('%s not included, skipping...', sid)
        elif inst_info[sid]['running'] is False:
            logging.debug('%s not running, skipping...', sid)
        elif inst_info[sid]['oracle_home'] is None:
            raise CustomException(Errors.E027, sid)
        else:
            instance    = Instance(tempdir, sid, inst_info[sid]['oracle_home'], inst_info[sid]['connectstring'])
            instance.get_jobs(args)
            total_jobs += instance.num_jobs
            logging.info('{0}: generating {1} workload reports'.format(sid, instance.num_jobs))
            instances.append(instance)

    msg = 'No reports'
    starttime = time.time()
    for instance in instances:
        shared    = Shared(args, instance, tempdir)
        dbidir    = os.path.join(tempdir, 'dbinfo')
        dbldir    = os.path.join(tempdir, 'log')
        awrdir    = os.path.join(tempdir, 'awr')
        splunkdir = os.path.join(tempdir, 'splunk')
        workers   = []

        info_processor(shared)

        generator = Process(target=job_generator, name='Generator', args=(shared,))
        generator.start()

        for i in range(shared.tasks):
            worker = Process(target=job_processor, name='Processor', args=(shared,))
            worker.start()
            workers.append(worker)

        logging.info('%s: Started %s SQLPlus sessions', shared.instance.sid, len(workers))

        while True:
            # Pick up completed AWR or Staspack files and move them to the archive
            time.sleep(1)
            filelist = os.listdir(awrdir)
            working  = any([worker.is_alive() for worker in workers])

            # Break if no more files AND no more workers
            if not any((filelist, working)):
                break

            for filename in filelist:
                path = os.path.join(awrdir, filename)

                # If requested, strip HTML file from SQL sections
                if args.strip and filename.endswith('.html'):
                    awrstrip(path, inplace=True)
                    logging.debug('Stripped SQL code from {0}'.format(filename))

                # Store the file and remove from FS
                archive.store(path, 'oracle/{0}/'.format(instance.sid) + filename)
                os.unlink(path)

                # Housekeeping
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

        if not args.quiet:
            print('')

        generator.join()
        logging.info('%s: Job generator completed', instance.sid)

        for worker in workers:
            worker.join()
            if worker.exitcode:
                raise CustomException(Errors.E022, worker.exitcode)

        logging.info('%s: Workers completed', instance.sid)

        # Pick up Splunk, DBInfo and Log files
        for filename in os.listdir(splunkdir):
            path = os.path.join(splunkdir, filename)
            archive.store(path, 'oracle/{0}/{1}'.format(instance.sid, filename))
            os.unlink(path)

        for filename in os.listdir(dbidir):
            path = os.path.join(dbidir, filename)
            archive.store(path, 'oracle/dbinfo/{0}'.format(filename))
            os.unlink(path)

        for filename in os.listdir(dbldir):
            path = os.path.join(dbldir, filename)
            archive.store(path, 'oracle/log/{0}'.format(filename))
            os.unlink(path)

        sys.stdout.write('\033[2K')
        sys.stdout.flush()

        if generator.exitcode:
            raise CustomException(Errors.E023, generator.exitcode)

    logging.info(msg)

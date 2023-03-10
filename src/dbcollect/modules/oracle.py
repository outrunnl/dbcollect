
import os, sys, re, tempfile, logging, time
from datetime import timedelta

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
    try:
        excluded = args.exclude.split(',') if args.exclude else []
        included = args.include.split(',') if args.include else []
        for sid, orahome in get_instances():
            if sid in excluded:
                logging.info('%s is excluded, skipping...', sid)
            elif included and not sid in included:
                logging.info('%s not included, skipping...', sid)
            else:
                instance    = Instance(tempdir, sid, orahome)
                total_jobs += instance.get_jobs(args)
                logging.info('{0}: {1} reports'.format(sid, total_jobs))
                instances.append(instance)
    except KeyboardInterrupt:
        pass

    logging.info('Retrieving {0} reports total'.format(total_jobs))

    try:
        msg = 'No reports'
        starttime = time.time()
        for instance in instances:
            shared = Shared(args, instance, tempdir)
            repdir = os.path.join(tempdir, 'reports')
            awrdir = os.path.join(tempdir, 'awr')
            proc_p = Process(target=producer, name='Producer', args=(shared,))
            proc_w = Process(target=worker, name='Worker', args=(shared,))
            proc_p.start()
            proc_w.start()
            while True:
                time.sleep(0.1)

                for filename in os.listdir(repdir):
                    path = os.path.join(repdir, filename)
                    archive.store(path, 'oracle/{0}/'.format(instance.sid) + filename)
                    os.unlink(path)

                filelist = os.listdir(awrdir)
                if not filelist and not proc_w.is_alive():
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
                    #print(msg)
                    sys.stdout.write('\033[2K{0}\033[G'.format(msg))
                    sys.stdout.flush()

            proc_p.join()
            shared.done.set()
            proc_w.join()

        sys.stdout.write('\033[2K')
        logging.info(msg)

    except KeyboardInterrupt:
        pass

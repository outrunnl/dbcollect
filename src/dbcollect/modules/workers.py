"""
workers.py - Multiprocessing classes for DBCollect
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, re, time, logging

from multiprocessing.queues import Full

from lib.errors import Errors, SQLError, SQLTimeout
from lib.functions import getscript
from lib.config import dbinfo_config
from lib.jsonfile import JSONFile
from lib.log import exception_handler

class Session():
    """SQL*Plus worker session"""
    def __init__(self, shared):
        self.tempdir  = shared.tempdir
        self.instance = shared.instance
        self.args     = shared.args
        self.proc     = self.instance.sqlplus(quiet=True)
        self.sid      = self.instance.sid
        self.start    = time.time()
        self.proc.stdin.write('WHENEVER SQLERROR EXIT SQL.SQLCODE\n')

    def __del__(self):
        """Send exit to SQLPlus if it is still running"""
        if self.proc.returncode is None:
            self.proc.communicate('exit;\n')

    @property
    def logfile(self):
        return os.path.join(self.tempdir, 'log', "{0}_sqlplus_{1}.log".format(self.sid, self.proc.pid))

    def send(self, s):
        """Send command to SQLPlus and log to logfile"""
        with open(self.logfile, 'a') as f:
            f.write(s)
        self.proc.stdin.write(s)

    def run(self, name, query, filename=None, header=None):
        """Run a query using SQLPlus"""

        # Restart SQLPlus if needed
        self.proc.poll()
        if self.proc.returncode is not None:
            logging.debug('rc={0}, Starting new SQLPlus process'.format(self.proc.returncode))
            self.proc = self.instance.sqlplus(quiet=True)
            self.proc.stdin.write('WHENEVER SQLERROR EXIT SQL.SQLCODE\n')

        # Setup paths and record start time
        spoolfile = os.path.join(self.tempdir, filename or 'out.txt')
        statfile  = os.path.join(self.tempdir, '{0}_status'.format(self.proc.pid))
        starttime = time.time()

        # Send commands to SQLPlus
        if header is not None:
            self.send(header)
        self.send('SPOOL {0}\n'.format(filename or 'out.txt'))
        self.send(query)
        self.send('\nSPOOL OFF\n')
        self.send('HOST touch {0}\n'.format(statfile))

        # Wait for the status file to appear and check for errors or timeouts
        while not os.path.exists(statfile):
            time.sleep(0.01)
            self.proc.poll()

            if self.proc.returncode is not None:
                with open(spoolfile) as f:
                    data = f.read()
                    for err, msg in re.findall(r'^(ORA-\d+):(.*)', data, re.M):
                        if err == 'ORA-00904':
                            raise SQLError(Errors.E040, name, self.sid, err, msg)
                logging.debug('\n%s', data)
                raise SQLError(Errors.E009, self.sid, self.proc.pid, self.proc.returncode, name)

            elapsed = round(time.time() - starttime,2)
            if elapsed > self.args.timeout * 60:
                self.proc.kill()
                raise SQLTimeout(Errors.E010, self.sid, self.proc.pid, round(elapsed), name)

        elapsed = round(time.time() - starttime,2)
        self.proc.poll()

        # Remove status file if exists
        try:
            os.unlink(statfile)
            status = 'OK'
        except OSError:
            status = 'ERROR'

        return elapsed, self.proc.returncode, status, spoolfile

    def genscripts(self):
        """ Generate the DBInfo scripts that need to be processed"""
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
        """ Run DBInfo and SPLUNK scripts"""
        logging.info('{0}: Running opatch lspatches'.format(self.sid))
        header = getscript('dbinfo/header.sql')

        # Get ORACLE_HOME patch info
        lspatches_cmd  = '{0} lspatches'.format(os.path.join(self.instance.orahome, 'OPatch/opatch'))
        inventory_info = JSONFile()
        inventory_info.execute(lspatches_cmd)
        inventory_info.save(os.path.join(self.tempdir, 'dbinfo', '{0}_patches.jsonp'.format(self.sid)))

        # Get Listener services
        listener_cmd  = '{0} status'.format(os.path.join(self.instance.orahome, 'bin/lsnrctl'))
        listener_info = JSONFile()
        listener_info.execute(listener_cmd, ORACLE_HOME=self.instance.orahome)
        listener_info.save(os.path.join(self.tempdir, 'dbinfo', '{0}_listener.jsonp'.format(self.sid)))

        logging.info('{0}: Running dbinfo scripts'.format(self.sid))
        for scriptname in self.genscripts():
            logging.debug('{0}: Running dbinfo script {1}'.format(self.sid, scriptname))

            query    = getscript('dbinfo/{0}'.format(scriptname))
            filename = '{0}_{1}'.format(self.sid, scriptname.replace('.sql','.txt'))
            savename = '{0}_{1}'.format(self.sid, scriptname.replace('.sql','.jsonp'))

            # Run the script and record the results
            elapsed, rc, status, outfile = self.run(scriptname, query, filename=filename, header=header)

            # Create JSONPlus file
            jsonfile = JSONFile(elapsed=elapsed, status=status, returncode=rc)
            jsonfile.dbinfo(self.instance, scriptname, outfile)
            jsonfile.save(os.path.join(self.tempdir, 'dbinfo', savename))

        if self.args.splunk:
            splunkheader = getscript('splunk/splunk_header.sql')
            if self.instance.status in ('STARTED','MOUNTED'):
                return
            logging.info('{0}: Running splunk scripts'.format(self.sid))
            if self.instance.version == 11:
                section = 'splunk_11'
            else:
                section = 'splunk_12'
            for scriptname in dbinfo_config[section]:
                logging.debug('{0}: Running splunk script {1}'.format(self.sid, scriptname))
                query = getscript('splunk/{0}'.format(scriptname))

                # Splunk files contain SPOOL so no filename is needed
                elapsed, rc, status, outfile = self.run(scriptname, query, header=splunkheader)

            # Move the finished SPLUNK files to the splunk dir
            for f in os.listdir(self.tempdir):
                path    = os.path.join(self.tempdir, f)
                newpath = os.path.join(self.tempdir, 'splunk', f)
                if os.path.isdir(path):
                    continue
                if f.endswith('.dsk') or f.startswith('capacity_'):
                    os.rename(path, newpath)

    @property
    def runtime(self):
        return round(time.time() - self.start, 2)

def info_processor(shared):
    """info processor - Runs the dbinfo scripts"""
    session = Session(shared)
    session.dbinfo()

    logging.info('%s: DBInfo processor finished, elapsed time %s seconds', shared.instance.sid, session.runtime)

@exception_handler
def job_generator(shared):
    """Producer - Submits AWR/SP jobs to the job queue"""
    timeout = shared.args.timeout * 60
    try:
        for job in shared.instance.jobs:
            shared.jobs.put(job, timeout=timeout)
    except Full:
        logging.error(Errors.E011, shared.instance.sid, timeout)
        sys.exit(11)
    except Exception as e:
        logging.exception(Errors.E001, e)
        sys.exit(20)
    finally:
        # Set the done flag even if failed
        shared.done.set()

@exception_handler
def job_processor(shared, n):
    """Worker process that handles SQL*Plus subprocesses"""
    session  = Session(shared)
    name = 'Worker {0}'.format(n)

    while True:
        if shared.jobs.empty() and shared.done.is_set():
            # Break the loop if job producer is done AND queue is empty
            break

        # Get the next job and run it
        job = shared.jobs.get(timeout=10)
        try:
            elapsed, rc, status, spoolfile = session.run(name, job.query, job.filename)
        
        except SQLTimeout as e:
            logging.error(*e.args)
            sys.exit(20)

        except SQLError as e:
            logging.error(*e.args)
            sys.exit(20)

        # Move the completed AWR/SP file to the awr dir
        tgtfile = os.path.join(shared.tempdir, 'awr', job.filename)
        os.rename(spoolfile, tgtfile)

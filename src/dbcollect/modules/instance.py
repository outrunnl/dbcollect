"""
instance.py - Manage Oracle database instances for DBCollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, logging
from subprocess import Popen, PIPE

from lib.functions import getscript
from lib.errors import ReportingError, SQLPlusError

class Job():
    """AWR/Statspack job definition"""
    def __init__(self, sid, dbid, reptype, instnum, beginsnap, endsnap, begintime, endtime):
        self.sid       = sid
        self.dbid      = dbid
        self.reptype   = reptype
        self.instnum   = instnum
        self.beginsnap = beginsnap
        self.endsnap   = endsnap
        self.begintime = begintime
        self.endtime   = endtime

    @property
    def filename(self):
        ext = 'html' if self.reptype == 'awr' else 'txt'
        return '{0}_{1}_{2}_{3}_{4}_{5}.{6}'.format(self.sid, self.instnum, self.reptype, self.beginsnap, self.endsnap, self.begintime, ext)

    @property
    def query(self):
        sql = getscript('{0}_report.sql'.format(self.reptype))
        return sql.format(filename=self.filename, dbid=self.dbid, inst=self.instnum, beginsnap=self.beginsnap, endsnap=self.endsnap)

class Instance():
    """Oracle Instance with SQL*Plus, scripts and other methods"""
    def __init__(self, tempdir, sid, orahome):
        self.tempdir   = tempdir
        self.sid       = sid
        self.orahome   = orahome
        self.jobs      = []
        self.scripts   = {}
        status       = self.query("SELECT status, regexp_substr(version, '\d+') FROM v$instance;\n").split()
        self.status  = status[0]
        self.version = int(status[1])

    def sqlplus(self, quiet=False):
        """
        Create a Popen() SQL*Plus session
        if quiet=True, redirect stdout to /dev/null.
        Note: SQL*Plus never writes to stderr.
        """
        env  = dict(ORACLE_HOME=self.orahome, ORACLE_SID=self.sid)
        path = os.path.join(self.orahome, 'bin/sqlplus')
        cmd  = (path, '-S', '-L', '/', 'as', 'sysdba')
        if quiet:
            stdout = open('/dev/null')
        else:
            stdout = PIPE
        try:
            if sys.version_info[0] == 2:
                proc = Popen(cmd, cwd=self.tempdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=PIPE)
            else:
                proc = Popen(cmd, cwd=self.tempdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=PIPE, encoding='utf-8')
        except OSError as e:
            raise SQLPlusError('Failed to run SQLPlus ({0}): {1}'.format(path, os.strerror(e.errno)))
        return proc

    def query(self, sql, header=None, onerror=True):
        """Run SQL*Plus query and return the output. Log errors if they appear"""
        proc = self.sqlplus()
        if onerror:
            proc.stdin.write("WHENEVER SQLERROR EXIT SQL.SQLCODE\n")
        proc.stdin.write("SET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n")
        if header:
            proc.stdin.write(header)
        out, _ = proc.communicate(sql)
        if proc.returncode:
            logging.debug('SQL*Plus output:\n{0}'.format(out))
            raise SQLPlusError('SQLPlus query exited with returncode {0}, see error log'.format(proc.returncode))
        return out.strip()

    def script(self, name, **kwargs):
        """Load a script, run it and return the output"""
        sql = getscript(name + '.sql')
        return self.query(sql, **kwargs).strip()

    def get_jobs(self, args):
        """Get the AWR or Statspack parameters and create jobs, return number of jobs"""
        if args.no_awr:
            return 0
        if not self.status == 'OPEN':
            logging.info('Instance {0} not open, continue...'.format(self.sid))
            return 0
        awrusage = int(self.script('awrusage'))
        spusage  = int(self.script('spusage'))
        if awrusage>0:
            reptype = 'awr'
            logging.info('{0}: AWR usage detected, generating reports '.format(self.sid))
        elif args.force_awr:
            reptype = 'awr'
            logging.warning("{0}: No prior AWR usage detected, continuing anyway (--force-awr)".format(self.sid))
        elif spusage>0:
            reptype = 'sp'
            logging.info('{0}: No awr, Statspack detected'.format(self.sid))
        elif args.ignore:
            logging.warning("Skipping {0}: No prior AWR usage or Statspack detected (--ignore)".format(self.sid))
            return 0
        else:
            raise ReportingError("No AWR or Statspack detected for {0} (try --force-awr or --ignore)".format(self.sid))

        loc    = 'Y' if args.local else 'N'
        header = 'define days   = {0}\ndefine offset = {1}\ndefine local  = {2}\n'.format(args.days, args.offset, loc)
        if reptype == 'awr':
            data   = self.script('getawrs', header=header)
        elif reptype == 'sp':
            data   = self.script('getsps', header=header)
        else:
            raise ValueError('Bad reporttype', reptype)
        for line in data.splitlines():
            dbid, instnum, beginsnap, endsnap, begintime, endtime = line.split(',')
            job = Job(self.sid, dbid, reptype, instnum, beginsnap, endsnap, begintime, endtime)
            self.jobs.append(job)
        return len(self.jobs)


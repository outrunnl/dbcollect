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
        return '{0}_{1}_{2}_{3}_{4}_{5}_{6}.{7}'.format(self.sid, self.dbid, self.instnum, self.reptype, self.beginsnap, self.endsnap, self.begintime, ext)

    @property
    def query(self):
        sql = getscript('{0}_report.sql'.format(self.reptype))
        return sql.format(filename=self.filename, dbid=self.dbid, inst=self.instnum, beginsnap=self.beginsnap, endsnap=self.endsnap)

def sqlplus2json(data):
    """
    Convert SQL*Plus metadata into json key/values
    """
    header = []
    info = {}
    for line in data.splitlines():
        if line.startswith('-----'):
            # separates header from data rows
            continue
        words = line.split('|')
        if len(words) < 2:
            # sepatates sections, reset header
            header = None
            continue
        if not header:
            header = words
            continue
        for k, v in zip(header, words):
            parameter = k.strip().lower()
            if parameter in ('instance_number', 'version_major'):
                value = int(v)
            else:
                value = v.strip()
            info[parameter] = value if value else None
    return info

class Instance():
    """Oracle Instance with SQL*Plus, scripts and other methods"""
    def __init__(self, tempdir, sid, orahome):
        self.tempdir   = tempdir
        self.sid       = sid
        self.orahome   = orahome
        self.jobs      = []
        self.scripts   = {}
        meta           = self.script('meta')
        self.instinfo  = sqlplus2json(meta)
        self.status    = self.instinfo['status']
        self.version   = self.instinfo['version_major']

    def sqlplus(self, quiet=False):
        """
        Create a Popen() SQL*Plus session
        if quiet=True, redirect stdout to /dev/null.
        Note: SQL*Plus never writes to stderr.
        """
        env  = { 'ORACLE_HOME': self.orahome, 'ORACLE_SID': self.sid }
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
        if header:
            proc.stdin.write(header)
        else:
            proc.stdin.write("SET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n")
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
        elif args.ignore_awr:
            logging.warning("Skipping {0}: No prior AWR usage or Statspack detected (--ignore)".format(self.sid))
            return 0
        else:
            raise ReportingError("No AWR or Statspack detected for {0} (try --force-awr or --ignore)".format(self.sid))

        inc_rac  = '0' if args.no_rac  else '1'
        inc_stby = '0' if args.no_stby else '1'
        inc_pack = '1' if args.force_awr else '0'
        header = 'define days = {0}\ndefine end_days = {1}\ndefine inc_rac = {2}\ndefine inc_stby = {3}\ndefine inc_pack = {4}\n'.format(args.days, args.end_days, inc_rac, inc_stby, inc_pack)
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

    def meta(self):
        info = {}
        info['oracle_sid']  = self.sid
        info['oracle_home'] = self.orahome
        info.update(self.instinfo)
        return info

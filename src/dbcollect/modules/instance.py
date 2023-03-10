
import os, sys, logging
from pkgutil import get_data
from subprocess import Popen, PIPE

from lib.errors import ReportingError

def loadscript(name):
    if sys.version_info[0] == 2:
        return get_data('sql', name + '.sql')
    else:
        return get_data('sql', name + '.sql').decode()

class Job():
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
        query = loadscript('{0}_report'.format(self.reptype))
        return query.format(filename=self.filename, dbid=self.dbid, inst=self.instnum, beginsnap=self.beginsnap, endsnap=self.endsnap)

class Instance():
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
        env  = dict(ORACLE_HOME=self.orahome, ORACLE_SID=self.sid)
        path = os.path.join(self.orahome, 'bin/sqlplus')
        cmd  = (path, '-S', '-L', '/', 'as', 'sysdba')
        if quiet:
            stdout = open('/dev/null')
        else:
            stdout = PIPE
        if sys.version_info[0] == 2:
            proc = Popen(cmd, cwd=self.tempdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=PIPE)
        else:
            proc = Popen(cmd, cwd=self.tempdir, bufsize=0, env=env, stdin=PIPE, stdout=stdout, stderr=PIPE, encoding='utf-8')
        return proc

    def query(self, sql, header=None):
        proc = self.sqlplus()
        proc.stdin.write("WHENEVER SQLERROR EXIT SQL.SQLCODE\n")
        proc.stdin.write("SET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n")
        if header:
            proc.stdin.write(header)
        out, _ = proc.communicate(sql)
        return out.strip()

    def script(self, name, header=None, **kwargs):
        query = loadscript(name)
        proc  = self.sqlplus()
        proc.stdin.write("SET tab off feedback off verify off heading off lines 1000 pages 0 trims on\n")
        if header:
            proc.stdin.write(header)
        out, _ = proc.communicate(query)
        return out

    def get_jobs(self, args):
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
            logging.warning("{0}: No prior AWR usage detected, continuing anyway (--force-awr)".format(self.instance.sid))
        elif spusage>0:
            reptype = 'sp'
            logging.info('{0}: No awr, Statspack detected'.format(self.instance.sid))
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

    def savescript(self, filename, *args):
        path = os.path.join(self.tempdir, 'reports', filename)
        data = ''
        for name in args:
            data += self.script(name)
        with open(path, 'w') as f:
            f.write(data)

    def info(self, args):
        if self.status == 'STARTED':
            self.savescript('dbinfo.txt', 'instance')
        elif self.status == 'MOUNTED':
            self.savescript('dbinfo.txt', 'database')
        if not self.status == 'OPEN':
            return
        if self.version < 11:
            self.savescript('dbinfo.txt', 'dbinfo')
        elif self.version >= 11:
            self.savescript('dbinfo.txt', 'dbinfo','dbinfo_11')
        if self.version >= 12:
            self.savescript('pdbinfo.txt', 'pdbinfo')
        if args.splunk:
            header = "set colsep ' '\nset timing off\nalter session set nls_date_format='YYYY-MM-DD';\n"
            if self.version < 11:
                ext = '10g'
            elif self.version == 11:
                ext = '11g'
            elif self.version > 11:
                ext = '12c'
            self.script('capacity_splunk_{0}'.format(ext), header=header)
            self.script('capacity_{0}'.format(ext), header=header)
            for f in os.listdir(self.tempdir):
                if f.startswith('capacity_') or f.endswith('.dsk'):
                    os.rename(os.path.join(self.tempdir, f), os.path.join(self.tempdir, 'reports', f))

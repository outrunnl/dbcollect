"""
syscollect.py - OS and system functions for dbcollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, json, re, platform, logging
from lib.config import linux_cmds, linux_files, aix_cmds, sun_cmds
from lib.fileformat import Datafile, JSONFile
from lib.functions import execute, listdir

# Check to continue even if platform is unknown?
def host_info(archive, args):
    """Get OS and run the corresponding OS/SAR module"""
    system = platform.system()
    logging.info('Collecting OS info ({0})'.format(system))
    if system == 'Linux':   linux_info(archive, args)
    elif system == 'AIX':   aix_info(archive, args)
    elif system == 'SunOS': sun_info(archive, args)
    else:
        logging.error("Unknown platform - {0}".format(system))


def zipexec(archive, cmd, prefix=None, tag=None):
    """Execute cmd and store output in archive using tag and header
    Store empty file if execute failed
    """
    df = Datafile()
    data = df.execute(cmd)
    if not tag:
        if cmd.startswith('lsblk -bp'):   tag = 'lsblk_bp'
        elif cmd.startswith('lsblk -P'):  tag = 'lsblk'
        elif cmd.startswith('rpm -qa'):   tag = 'rpm_qa_queryformat'
        elif cmd.startswith('svmon'):     tag = 'svmon_g_o'
        elif cmd.startswith('lsdev -c'):  tag = 'lsdev_c_adapter'
        elif cmd.startswith('zpool'):     tag = '_'.join(cmd.split()[:2])
        else:
            tag = re.sub(r'[^0-9a-zA-Z_ ]', '', '_'.join(cmd.split()))
    if not prefix:
        prefix = 'cmd'
    archive.writestr(prefix + '/' + tag, data)

def zipfile(archive, path):
    df = Datafile()
    data = df.file(path)
    if data:
        archive.writestr(path, data)

def linux_lsblk(archive):
    out, err, rc = execute('lsblk -V')
    version = out.split()[-1]
    if version.startswith('2.1'):
        cmd = 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched'
    else:
        cmd = 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched,wwn,hctl,pkname'
    zipexec(archive, cmd)

def linux_info(archive, args):
    """System/SAR info for Linux"""
    hostinfo = JSONFile('hostinfo')
    info = {}
    for cmd in ('sestatus','uptime'):
        out, err, rc = execute(cmd)
        if not rc==0:
            info['{0}_error'.format(cmd)] = { 'command': cmd, 'stdout': out, 'stderr': err, 'rc': rc }
        if cmd == 'sestatus':
            out = out.split()[-1]
        info[cmd] = out.strip()

    for file in os.listdir('/sys/class/dmi/id'):
        path = os.path.join('/sys/class/dmi/id', file)
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    data = f.read()
                    info[file] = data.rstrip()
            except IOError:
                info[file] = None
    hostinfo.set('hostinfo', info)
    archive.writestr('hostinfo.json', hostinfo.dump())

    # TODO:
    # powerpath / scaleio? -> Need root?
    diskinfo = JSONFile('diskinfo')
    disklist = []
    out, err, rc = execute('lsblk -dno name')
    for dev in out.rstrip().splitlines():
        info = { 'name': dev }
        for file in  ['dev', 'device/model','device/rev','device/queue_depth','device/vendor','device/serial','size','queue/scheduler']:
            path = os.path.join('/sys/class/block/{0}/{1}'.format(dev, file))
            var = file.split('/')[-1]
            try:
                with open(path) as f:
                    data = f.read().strip()
                    if var in ('queue_depth','size'):
                        data = int(data)
                    info[var] = data
            except IOError as e:
                info[var] = None
        cmd = 'udevadm info -q symlink -n {0}'.format(dev)
        out, err, rc = execute(cmd)
        if not rc==0:
            info['udevadm_cmd'] = { 'command': cmd, 'stdout': out, 'stderr': err, 'rc': rc }
        info['symlinks'] = out.split()
        disklist.append(info)
    diskinfo.set('disks', disklist)
    archive.writestr('diskinfo.json', diskinfo.dump())

    nicinfo = JSONFile('interfaces')
    niclist = []
    for dev in listdir('/sys/class/net'):
        if dev == 'lo':
            continue
        info = { 'name': dev }
        dir = os.path.join('/sys/class/net', dev)
        if not os.path.isdir(dir):
            continue
        for var in ['mtu', 'speed', 'address']:
            path = os.path.join(dir, var)
            try:
                with open(path) as f:
                    data = f.read().rstrip()
                    if var in ('mtu','speed'):
                        data = int(data)
                    info[var] = data
            except:
                info[var] = None
        niclist.append(info)
    nicinfo.set('interfaces', niclist)
    archive.writestr('nicinfo.json', nicinfo.dump())

    for cmd in linux_cmds:
        zipexec(archive, cmd)
    linux_lsblk(archive)
    for file in linux_files:
        zipfile(archive, file)
    for f in listdir('/etc/udev/rules.d/'):
        path = os.path.join('/etc/udev/rules.d/', f)
        if os.path.isfile(path) and f.endswith('.rules'):
            zipfile(archive, path)

    if not args.no_sar:
        logging.info('Collecting Linux SAR files')
        for sarfile in listdir('/var/log/sa'):
            path = os.path.join('/var/log/sa', sarfile)
            if sarfile.startswith('sa'):
                if sarfile.startswith('sar'):
                    continue
                if sarfile.endswith('.xz'):
                    continue
                archive.store(path)

def aix_info(archive, args):
    """System/SAR info for AIX (pSeries)"""
    logging.info('Collecting AIX System info')
    for cmd in aix_cmds:
        zipexec(archive, cmd)
    disks, err, rc = execute('lsdev -Cc disk -Fname')
    nics, err, rc = execute('ifconfig -l')
    vgs, err, rc =  execute('lsvg')
    logging.info('Collecting AIX Disk info')
    for disk in disks.splitlines():
        prefix = 'disk/{0}'.format(disk)
        zipexec(archive, 'getconf DISK_SIZE /dev/{0}'.format(disk), prefix=prefix, tag='disksize')
        zipexec(archive, 'lscfg -vpl %s' % disk, prefix=prefix, tag='lscfg')
        zipexec(archive, 'lspath -l %s -F parent,status' % disk, prefix=prefix, tag='lspath')
        zipexec(archive, 'lsattr -El %s' % disk, prefix=prefix, tag='lsattr')
    logging.info('Collecting AIX Network info')
    for nic in nics.split():
        if nic.startswith('lo'): continue
        prefix = 'nic/{0}'.format(nic)
        zipexec(archive, 'lsattr -E -l %s -F description,value' % nic, prefix=prefix, tag='lsattr')
        zipexec(archive, 'entstat -d %s' % nic, prefix=prefix, tag='entstat')
    logging.info('Collecting AIX LVM info')
    for vg in vgs.splitlines():
        prefix = 'lvm/{0}'.format(vg)
        zipexec(archive, 'lsvg -l %s' % vg, prefix=prefix, tag='lvs')
        zipexec(archive, 'lsvg -p %s' % vg, prefix=prefix, tag='pvs')
    if not args.no_sar:
        logging.info('Collecting UNIX SAR reports')
        for sarfile in listdir('/var/adm/sa'):
            path = os.path.join('/var/adm/sa', sarfile)
            if sarfile.startswith('sa'):
                if sarfile.startswith('sar'):
                    continue
                prefix = 'sar/{0}'.format(sarfile)
                zipexec(archive, 'sar -uf %s' % path, prefix=prefix, tag='cpu')
                zipexec(archive, 'sar -bf %s' % path, prefix=prefix, tag='block')
                zipexec(archive, 'sar -df %s' % path, prefix=prefix, tag='disk')
                zipexec(archive, 'sar -rf %s' % path, prefix=prefix, tag='swap')

def sun_info(archive, args):
    """System/SAR info for Sun Solaris (SPARC or Intel)"""
    logging.info('Collecting Solaris System info')
    for cmd in sun_cmds:
        zipexec(archive, cmd)
    if not args.no_sar:
        logging.info('Collecting UNIX SAR reports')
        for sarfile in listdir('/var/adm/sa'):
            path = os.path.join('/var/adm/sa', sarfile)
            if sarfile.startswith('sa'):
                if sarfile.startswith('sar'):
                    continue
                prefix = 'sar/{0}'.format(sarfile)
                zipexec(archive, 'sar -uf %s' % path, prefix=prefix, tag='cpu')
                zipexec(archive, 'sar -bf %s' % path, prefix=prefix, tag='buffer')
                zipexec(archive, 'sar -df %s' % path, prefix=prefix, tag='disk')
                zipexec(archive, 'sar -rf %s' % path, prefix=prefix, tag='swap')

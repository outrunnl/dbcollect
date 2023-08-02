"""
syscollect.py - OS and system functions for dbcollect
Copyright (c) 2023 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

import os, sys, json, re, platform, logging
from lib.config import linux_config, aix_config, sunos_config
from lib.jsonfile import JSONFile
from lib.functions import execute, listdir

# Check to continue even if platform is unknown?
def host_info(archive, args):
    """Get OS and run the corresponding OS/SAR module"""
    system = platform.system()
    logging.info('Collecting OS info ({0})'.format(system))
    if system == 'Linux':
        linux_info(archive, args)
    elif system == 'AIX':
        aix_info(archive, args)
    elif system == 'SunOS':
        sun_info(archive, args)
    else:
        logging.error("Unknown platform - {0}".format(system))

def sar_info(archive, args):
    """Get UNIX SAR reports"""
    if args.no_sar:
        return
    logging.info('Collecting UNIX SAR reports')
    sarpath = '/var/adm/sa'
    sarinfo = JSONFile()
    sarinfo.dir(sarpath)
    archive.writestr('sarinfo.json', sarinfo.dump())

    for sarfile in listdir(sarpath):
        path = os.path.join(sarpath, sarfile)
        if sarfile.startswith('sar'):
            continue
        elif sarfile.startswith('sa'):
            df_cpu   = JSONFile(cmd='sar -uf {0}'.format(path))
            df_block = JSONFile(cmd='sar -bf {0}'.format(path))
            df_disk  = JSONFile(cmd='sar -df {0}'.format(path))
            df_swap  = JSONFile(cmd='sar -rf {0}'.format(path))
            archive.writestr('sar/{0}_{1}.jsonp'.format(sarfile, 'cpu'), df_cpu.jsonp())
            archive.writestr('sar/{0}_{1}.jsonp'.format(sarfile, 'block'), df_block.jsonp())
            archive.writestr('sar/{0}_{1}.jsonp'.format(sarfile, 'disk'), df_disk.jsonp())
            archive.writestr('sar/{0}_{1}.jsonp'.format(sarfile, 'swap'), df_swap.jsonp())

def linux_info(archive, args):
    """System/SAR info for Linux"""
    info = {}
    for cmd in ('sestatus','uptime'):
        out, err, rc = execute(cmd)
        if not rc==0:
            info['{0}_error'.format(cmd)] = { 'command': cmd, 'stdout': out, 'stderr': err, 'rc': rc }
        if cmd == 'sestatus':
            out = out.split()[-1]
        info[cmd] = out.strip()

    for file in os.listdir('/sys/class/dmi/id'):
        if file in ('modalias','uevent'):
            continue
        path = os.path.join('/sys/class/dmi/id', file)
        if os.path.isfile(path):
            try:
                with open(path) as f:
                    data = f.read()
                    info[file] = data.rstrip()
            except IOError:
                info[file] = None

    hostinfo = JSONFile()
    hostinfo.set('hostinfo', info)
    archive.writestr('hostinfo.json', hostinfo.dump())

    # TODO:
    # powerpath / scaleio? -> Need root?

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

    diskinfo = JSONFile()
    diskinfo.set('diskinfo', {'disklist': disklist })
    archive.writestr('diskinfo.json', diskinfo.dump())

    niclist = []
    for dev in listdir('/sys/class/net'):
        if dev == 'lo':
            continue
        info = { 'name': dev }
        dir = os.path.join('/sys/class/net', dev)
        if not os.path.isdir(dir):
            continue
        for var in ['mtu', 'speed', 'address','duplex']:
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

    nicinfo = JSONFile()
    nicinfo.set('nicinfo', {'niclist': niclist} )
    archive.writestr('nicinfo.json', nicinfo.dump())

    for tag, cmd in linux_config['commands'].items():
        if tag in ('lsblk_long','lsblk_bp'):
            out, err, rc = execute('lsblk -V')
            version = (out + err).split()[-1]
            if version.startswith('2.1'):
                cmd = cmd.replace(',wwn,hctl,pkname','')
                cmd = cmd.replace('-bp','-b')
        df = JSONFile(cmd=cmd)
        archive.writestr('cmd/{0}.jsonp'.format(tag), df.jsonp())

    for file in linux_config['files']:
        df = JSONFile(path=file)
        archive.writestr(file + '.jsonp', df.jsonp())

    for file in listdir('/etc/udev/rules.d/'):
        path = os.path.join('/etc/udev/rules.d/', file)
        if os.path.isfile(path) and file.endswith('.rules'):
            df = JSONFile(path=path)
            archive.writestr(path + '.jsonp', df.jsonp())

    if not args.no_sar:
        logging.info('Collecting Linux SAR files')
        sarinfo = JSONFile()
        sardirs = ('/var/log/sa', '/var/log/sysstat')
        sarinfo.dir(*sardirs)
        archive.writestr('sarinfo.json', sarinfo.dump())
        for sardir in sardirs:
            for sarfile in listdir(sardir):
                path = os.path.join(sardir, sarfile)
                if sarfile.startswith('sa'):
                    if sarfile.startswith('sar'):
                        continue
                    if sarfile.endswith('.xz'):
                        continue
                    archive.store(path)


def aix_info(archive, args):
    """System/SAR info for AIX (pSeries)"""
    logging.info('Collecting AIX System info')

    for tag, cmd in aix_config['commands'].items():
        df = JSONFile(cmd=cmd)
        archive.writestr('cmd/{0}.jsonp'.format(tag), df.jsonp())

    for file in aix_config['files']:
        df = JSONFile(path=file)
        archive.writestr(file + '.jsonp', df.jsonp())

    disks, err, rc = execute('lsdev -Cc disk -Fname')
    nics, err, rc = execute('ifconfig -l')
    vgs, err, rc =  execute('lsvg')

    logging.info('Collecting AIX Disk info')
    for disk in disks.splitlines():
        df_size = JSONFile(cmd='getconf DISK_SIZE /dev/{0}'.format(disk))
        df_cfg  = JSONFile(cmd='lscfg -vpl {0}'.format(disk))
        df_path = JSONFile(cmd='lspath -l {0} -F parent,status'.format(disk))
        df_attr = JSONFile(cmd='lsattr -El {0}'.format(disk))
        archive.writestr('disk/{0}_disksize.jsonp'.format(disk), df_size.jsonp())
        archive.writestr('disk/{0}_lscfg.jsonp'.format(disk), df_cfg.jsonp())
        archive.writestr('disk/{0}_lspath.jsonp'.format(disk), df_path.jsonp())
        archive.writestr('disk/{0}_lsattr.jsonp'.format(disk), df_attr.jsonp())

    logging.info('Collecting AIX Network info')
    for nic in nics.split():
        if nic.startswith('lo'):
            continue
        df_attr = JSONFile(cmd='lsattr -E -l {0} -F description,value'.format(nic))
        df_stat = JSONFile(cmd='entstat -d {0}'.format(nic))
        archive.writestr('nic/{0}_lsattr.jsonp'.format(nic), df_attr.jsonp())
        archive.writestr('nic/{0}_entstat.jsonp'.format(nic), df_stat.jsonp())

    logging.info('Collecting AIX LVM info')
    for vg in vgs.splitlines():
        df_lvs =  JSONFile(cmd='lsvg -l {0}'.format(vg))
        df_pvs =  JSONFile(cmd='lsvg -p {0}'.format(vg))
        archive.writestr('lvm/{0}_lvs.jsonp'.format(vg), df_lvs.jsonp())
        archive.writestr('lvm/{0}_pvs.jsonp'.format(vg), df_pvs.jsonp())

    sar_info(archive, args)

def sun_info(archive, args):
    """System/SAR info for Sun Solaris (SPARC or Intel)"""
    logging.info('Collecting Solaris System info')
    for tag, cmd in sunos_config['commands'].items():
        df = JSONFile(cmd=cmd)
        archive.writestr('cmd/{0}.jsonp'.format(tag), df.jsonp())

    for file in sunos_config['files']:
        df = JSONFile(path=file)
        archive.writestr(file + '.jsonp', df.jsonp())

    sar_info(archive, args)

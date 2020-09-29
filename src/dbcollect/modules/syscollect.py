"""
syscollect.py - OS and system functions for dbcollect
Copyright (c) 2020 - Bart Sjerps <bart@outrun.nl>
License: GPLv3+
"""

"""
Collect Linux/UNIX OS config and performance (SAR) data
"""

import os, sys, platform
from lib import *

def zipexec(archive, tag, cmd, **kwargs):
    """Execute cmd and store output in archive using tag
    Store empty file if execute failed
    """
    out = execute(cmd, **kwargs)
    if not out:
        archive.writestr('cmd/' + tag, '')
    else:
        archive.writestr('cmd/' + tag, out.encode('utf-8'))

# Check to continue even if platform is unknown?
def hostinfo(archive, args):
    """Get OS and run the corresponding OS/SAR module"""
    system = platform.system()
    logging.info('Collecting OS info ({0})'.format(system))
    if system == 'Linux':   linux_info(archive, args)
    elif system == 'AIX':   aix_info(archive, args)
    elif system == 'SunOS': sun_info(archive, args)
    else:
        logging.error("Unknown platform - {0}".format(system))

def linux_info(archive, args):
    """System/SAR info for Linux"""
    if os.path.isfile('/lib64/ld-2.12.so'): # Legacy EL 6
        lsblk = 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched'
    else:
        lsblk = 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched,wwn,hctl,pkname'
    zipexec(archive, 'lscpu'     , 'lscpu')
    zipexec(archive, 'lsscsi'    , 'lsscsi')
    zipexec(archive, 'sestatus'  , 'sestatus')
    zipexec(archive, 'lsmod'     , 'lsmod')
    zipexec(archive, 'dmesg'     , 'dmesg')
    zipexec(archive, 'psef'      , 'ps -ef')
    zipexec(archive, 'psfaux'    , 'ps faux')
    zipexec(archive, 'lsblk'     , lsblk)
    zipexec(archive, 'dfpt'      , 'df -PT')
    zipexec(archive, 'iplink'    , 'ip -o link show')
    zipexec(archive, 'ipaddr'    , 'ip -o addr show')
    zipexec(archive, 'rpmqf'     , 'rpm -qa --queryformat %{name}|%{version}|%{release}|%{summary}\\n')
    zipexec(archive, 'sysctla'   , 'sysctl -a', hide_errors=True)
    for file in ['/proc/cpuinfo',
        '/proc/meminfo',
        '/proc/filesystems',
        '/proc/partitions',
        '/proc/devices',
        '/proc/mounts',
        '/proc/mdstat',
        '/proc/misc',
        '/proc/uptime',
        '/etc/os-release',
        '/etc/issue',
        '/etc/motd',
        '/etc/multipath.conf',
        '/sys/class/dmi/id/sys_vendor',
        '/sys/class/dmi/id/product_name',
        '/sys/class/dmi/id/product_uuid',
        '/sys/class/dmi/id/board_name',
        '/sys/class/dmi/id/board_vendor',
        '/sys/class/dmi/id/chassis_vendor']:
        archive.store(file)
    for f in os.listdir('/etc/udev/rules.d/'):
        path = os.path.join('/etc/udev/rules.d/', f)
        if os.path.isfile(path) and f.endswith('.rules'):
            archive.store(path)
    # oraInst.loc
    # numa?
    # powerpath / scaleio?

    for dev in execute('lsblk -dno name').splitlines():
        for var in  ['model','rev','dev','queue_depth','vendor','serial']:
            path = os.path.join('/sys/class/block/{0}/device/{1}'.format(dev, var))
            if os.path.isfile(path):
                archive.store(path)
        archive.writestr('disks/{0}-links'.format(dev), execute('udevadm info -q symlink -n {0}'.format(dev)))

    for dev in os.listdir('/sys/class/net'):
        if dev == 'lo':
            continue
        dir = os.path.join('/sys/class/net', dev)
        if not os.path.isdir(dir):
            continue
        for var in ['mtu', 'speed', 'address']:
            path = os.path.join(dir, var)
            if os.path.isfile(path):
                archive.store(path)
    if not args.no_sar:
        logging.info('Collecting Linux SAR files')
        for sarfile in listdir('/var/log/sa'):
            path = os.path.join('/var/log/sa', sarfile)
            if sarfile.startswith('sa'):
                if sarfile.startswith('sar'):
                    continue
                archive.store(path)

def aix_info(archive, args):
    """System/SAR info for AIX (pSeries)"""
    zipexec(archive, 'prtconf.txt',  'prtconf')
    zipexec(archive, 'lparstat.txt', 'lparstat -i')
    zipexec(archive, 'svmon.txt',    'svmon -G -O summary=basic,unit=KB')
    zipexec(archive, 'dfpk.txt',     'df -Pk')
    zipexec(archive, 'lsfsc.txt',    'lsfs -c')
    zipexec(archive, 'adapters.txt', 'lsdev -c adapter -F name,status,description')
    for disk in execute('lsdev -Cc disk -Fname').splitlines():
        zipexec(archive, 'disks/{0}-size'.format(disk),   'getconf DISK_SIZE /dev/{0}'.format(disk))
        zipexec(archive, 'disks/{0}-lscfg'.format(disk),  'lscfg -vpl %s' % disk)
        zipexec(archive, 'disks/{0}-lspath'.format(disk), 'lspath -l %s -F parent,status' % disk)
        zipexec(archive, 'disks/{0}-lsattr'.format(disk), 'lsattr -El %s' % disk)
    for nic in execute('ifconfig -l').split():
        if nic.startswith('lo'): continue
        zipexec(archive, 'nics/{0}-lsattr'.format(nic), 'lsattr -E -l %s -F description,value' % nic)
        zipexec(archive, 'nics/{0}-entstat'.format(nic), 'entstat -d %s' % nic)
    for vg in execute('lsvg').splitlines():
        zipexec(archive, 'vgs/{0}-lsvg_l'.format(vg), 'lsvg -l %s' % vg)
        zipexec(archive, 'vgs/{0}-lsvg_p'.format(vg), 'lsvg -p %s' % vg)
    for sarfile in os.listdir('/var/adm/sa'):
        path = os.path.join('/var/adm/sa', sarfile)
        if sarfile.startswith('sa'):
            zipexec(archive, 'sar/{0}-cpu'.format(sarfile),  'sar -uf %s' % path)
            zipexec(archive, 'sar/{0}-disk'.format(sarfile), 'sar -df %s' % path)
            zipexec(archive, 'sar/{0}-swap'.format(sarfile), 'sar -rf %s' % path)

def sun_info(archive, args):
    """System/SAR info for Sun Solaris (SPARC or Intel)"""
    zipexec(archive, 'prtconf.txt',      'prtconf')
    zipexec(archive, 'prtdiag.txt',      'prtdiag')
    zipexec(archive, 'psrinfo.txt',      'psrinfo')
    zipexec(archive, 'psrinfo_t.txt',    'psrinfo -t')
    zipexec(archive, 'psrinfo_v0.txt',   'psrinfo -v 0')
    zipexec(archive, 'psrinfo_pv0.txt',  'psrinfo -pv 0')
    zipexec(archive, 'iostat_enr.txt',   'iostat -Enr')
    zipexec(archive, 'df_k.txt',         'df -k')
    zipexec(archive, 'df_n.txt',         'df -n') # df_k first
    zipexec(archive, 'zpool_list.txt',   'zpool list -o name,size,free,allocated -H')
    zipexec(archive, 'zpool_status.txt', 'zpool status')
    zipexec(archive, 'zfs_list.txt',     'zfs list')
    zipexec(archive, 'ifconfig.txt',     'ifconfig -a')
    zipexec(archive, 'dladm-phys.txt',   'dladm show-phys')
    zipexec(archive, 'dladm-link.txt',   'dladm show-link')
    zipexec(archive, 'dladm-part.txt',   'dladm show-part')
    zipexec(archive, 'dladm-vlan.txt',   'dladm show-vlan')
    zipexec(archive, 'dladm-vnic.txt',   'dladm show-vnic')
    for sarfile in os.listdir('/var/adm/sa'):
        path = os.path.join('/var/adm/sa', sarfile)
        if sarfile.startswith('sa'):
            zipexec(archive, 'sar/{0}-cpu'.format(sarfile),    'sar -uf %s' % path)
            zipexec(archive, 'sar/{0}-buffer'.format(sarfile), 'sar -bf %s' % path)
            zipexec(archive, 'sar/{0}-disk'.format(sarfile),   'sar -df %s' % path)
            zipexec(archive, 'sar/{0}-swap'.format(sarfile),   'sar -rf %s' % path)

#!/usr/bin/env python
versioninfo = {
    'author': "Bart Sjerps <info@dirty-cache.com>",
    'copyright': "Copyright 2023, Bart Sjerps",
    'license': "GPLv3+, https://www.gnu.org/licenses/gpl-3.0.html",
    'version': "1.12.7"
}

settings = {
    'logpath': "/tmp/dbcollect.log",
}

linux_config = {
    'commands': {
        'lscpu': 'lscpu',
        'lsscsi': 'lsscsi',
        'lsmod': 'lsmod',
        'dmesg': 'dmesg',
        'ps_ef': 'ps -ef',
        'ps_faux': 'ps faux',
        'df_PT': 'df -PT',
        'ip_links': 'ip -o link show',
        'ip_addrs': 'ip -o addr show',
        'sysctl': 'sysctl -a',
        'numactl_hw': 'numactl --hardware',
        'numactl_show': 'numactl --show',
        'lspci': 'lspci',
        'lsblk_bp': 'lsblk -bp',
        'lsblk_long': 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched,wwn,hctl,pkname',
        'rpm_packages': 'rpm -qa --queryformat %{name}|%{version}|%{release}|%{summary}\\n',
    },
    'files': [
        '/proc/cmdline',
        '/proc/cpuinfo',
        '/proc/meminfo',
        '/proc/filesystems',
        '/proc/partitions',
        '/proc/devices',
        '/proc/mounts',
        '/proc/mdstat',
        '/proc/modules',
        '/proc/misc',
        '/proc/uptime',
        '/etc/os-release',
        '/etc/system-release',
        '/etc/issue',
        '/etc/motd',
        '/etc/multipath.conf',
        '/etc/oratab',
    ],
}

aix_config = {
    'commands': {
        'prtconf': 'prtconf',
        'ps_ef': 'ps -ef',
        'lparstat': 'lparstat -i',
        'svmon': 'svmon -G -O summary=basic,unit=KB',
        'df_pk': 'df -Pk',
        'lsfs': 'lsfs -c',
        'lsdev_adapters': 'lsdev -c adapter -F name,status,description'
    },
    'files': [
        '/var/opt/oracle/oratab',
    ],
}

sunos_config = {
    'commands': {
        'prtconf': 'prtconf',
        'prtdiag': 'prtdiag',
        'psrinfo': 'psrinfo',
        'psrinfo_t': 'psrinfo -t',
        'psrinfo_v0': 'psrinfo -v 0',
        'psrinfo_pv0': 'psrinfo -pv 0',
        'iostat': 'iostat -Enr',
        'ps_ef': 'ps -ef',
        'df_k': 'df -k',
        'df_n': 'df -n',
        'zpool_list': 'zpool list -o name,size,free,allocated -H',
        'zpool_status': 'zpool status',
        'zfs_list': 'zfs list',
        'ifconfig': 'ifconfig -a',
        'dladm_phys': 'dladm show-phys',
        'dladm_link': 'dladm show-link',
        'dladm_part': 'dladm show-part',
        'dladm_vlan': 'dladm show-vlan',
        'dladm_vnic': 'dladm show-vnic',
        'zoneadm_list': 'zoneadm list -vc'
    },
    'files': [
        '/etc/release',
        '/var/opt/oracle/oratab',
    ],
}

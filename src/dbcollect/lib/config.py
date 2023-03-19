#!/usr/bin/env python
versioninfo = {
    'author': "Bart Sjerps <info@dirty-cache.com>",
    'copyright': "Copyright 2023, Bart Sjerps",
    'license': "GPLv3+, https://www.gnu.org/licenses/gpl-3.0.html",
    'version': "1.11.1"
}

linux_cmds = [
    'lscpu',
    'lsscsi',
    'lsmod',
    'dmesg',
    'ps -ef',
    'ps faux',
    'df -PT',
    'ip -o link show',
    'ip -o addr show',
    'rpm -qa --queryformat %{name}|%{version}|%{release}|%{summary}\\n',
    'sysctl -a',
    'numactl --hardware',
    'numactl --show',
    'lspci',
    'lsblk -bp',
    ]

linux_files = [
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
    ]

aix_cmds = [
    'prtconf',
    'ps -ef',
    'lparstat -i',
    'svmon -G -O summary=basic,unit=KB',
    'df -Pk',
    'lsfs -c',
    'lsdev -c adapter -F name,status,description'
    ]

sun_cmds = [
    'prtconf',
    'prtdiag',
    'psrinfo',
    'psrinfo -t',
    'psrinfo -v 0',
    'psrinfo -pv 0',
    'iostat -Enr',
    'ps -ef',
    'df -k',
    'df -n',
    'zpool list -o name,size,free,allocated -H',
    'zpool status',
    'zfs list',
    'ifconfig -a',
    'dladm show-phys',
    'dladm show-link',
    'dladm show-part',
    'dladm show-vlan',
    'dladm show-vnic',
    'zoneadm list -vc'
    ]

if __name__ == '__main__':
    # print version if called directly - for building releases
    print(versioninfo['version'])

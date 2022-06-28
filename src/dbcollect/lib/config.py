#!/usr/bin/env python
versioninfo = {
    'author': "Bart Sjerps <info@dirty-cache.com>",
    'copyright': "Copyright 2021, Bart Sjerps",
    'license': "GPLv3+, https://www.gnu.org/licenses/gpl-3.0.html",
    'version': "1.9.3"
}

linux_cmds = [
    'lscpu',
    'lsscsi',
    'sestatus',
    'lsmod',
    'dmesg',
    'ps -ef',
    'ps faux',
    'df -PT',
    'ip -o link show',
    'ip -o addr show',
    'rpm -qa --queryformat %{name}|%{version}|%{release}|%{summary}\\n',
    'sysctl -a',
    'numactl -H',
    'numactl -s',
    ]

linux_files = [
    '/proc/cpuinfo',
    '/proc/meminfo',
    '/proc/filesystems',
    '/proc/partitions',
    '/proc/devices',
    '/proc/mounts',
    '/proc/mdstat',
    '/proc/misc',
    '/proc/uptime',
    '/etc/os-release',
    '/etc/system-release',
    '/etc/issue',
    '/etc/motd',
    '/etc/multipath.conf',
    '/etc/oratab',
    '/sys/class/dmi/id/sys_vendor',
    '/sys/class/dmi/id/product_name',
    '/sys/class/dmi/id/product_uuid',
    '/sys/class/dmi/id/board_name',
    '/sys/class/dmi/id/board_vendor',
    '/sys/class/dmi/id/chassis_vendor'
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

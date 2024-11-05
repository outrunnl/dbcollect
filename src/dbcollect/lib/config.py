"""
config.py - DBCollect configuration/settings
Copyright (c) 2024 - Bart Sjerps <bart@dirty-cache.com>
License: GPLv3+
"""

versioninfo = {
    'author': "Bart Sjerps <info@dirty-cache.com>",
    'copyright': "Copyright 2024, Bart Sjerps",
    'license': "GPLv3+, https://www.gnu.org/licenses/gpl-3.0.html",
    'version': "1.17.4"
}

settings = {
    'logpath': "/tmp/dbcollect.log",
}

dbinfo_config = {
    'basic': [
        'instance.sql',
        'database.sql',
        'rac.sql',
        'session_privileges.sql',
        'tbl_privileges.sql',
        'dbfiles.sql',
        'dbsize.sql',
        'asmdiskgroups.sql',
        'asmdisks.sql',
        'asmsummary.sql',
        'parameters.sql',
        'osstats.sql',
        'redologs.sql',
        'archivelogs.sql',
        'archivesummary.sql',
        'bctracking.sql',
        'flashback.sql',
        'banner.sql',
    ],
    'common': [
        'rmanconfig.sql',
        'backupjobs.sql',
        'backups.sql',
        'awrretention.sql',
        'awrsnaps.sql',
        'dnfs.sql',
        'features.sql',
        'watermarks.sql',
        'archive_dest_status.sql',
        #'sleep.sql',
        #'error.sql',
    ],
    'oracle11': [
        'db_tablespaces.sql',
        'db_tsfiles.sql',
        'db_tempfiles.sql',
        'db_freespace.sql',
        'db_tempspace.sql',
        'db_segments.sql',
        'db_recyclebin.sql',
        'db_compression.sql',
    ],
    'oracle12': [
        'dataguard_config.sql',
        'pdb_cdbinfo.sql',
        'pdb_databases.sql',
        'pdb_tablespaces.sql',
        'pdb_tsfiles.sql',
        'pdb_tempfiles.sql',
        'pdb_freespace.sql',
        'pdb_tempspace.sql',
        'pdb_segments.sql',
        'pdb_recyclebin.sql',
        'pdb_compression.sql',
    ],
    'splunk_11': [
        'capacity_11g.sql',
        'capacity_splunk_11g.sql'
    ],
    'splunk_12': [
        'capacity_12c.sql',
        'capacity_splunk_12c.sql'
    ],
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
        'sar_v': 'sar -V',
        'numactl_hw': 'numactl --hardware',
        'numactl_show': 'numactl --show',
        'lspci': 'lspci',
        'lsblk_b': 'lsblk -b',
        'lsblk_el6': 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched',
        'lsblk_long': 'lsblk -PbnDo name,maj:min,kname,type,label,size,fstype,sched,wwn,hctl,pkname,serial,vendor,model',
        'rpm_packages': 'rpm -qa --queryformat %{name}|%{version}|%{release}|%{summary}\\n',
        'dpkg_l': 'dpkg -l',
        'ulimit_a': 'ulimit -a',
        'systemctl_units': 'systemctl list-units',
        'systemctl_timers': 'systemctl list-timers',
    },
    'rootcommands': {
        'multipath_ll': '/usr/sbin/multipath -ll',
        'vgs': 'vgs --separator \t --units m --nosuffix -o +fmt,uuid',
        'pvs': 'pvs --separator \t --units m --nosuffix -o +uuid,missing,in_use',
        'lvs': 'lvs --separator \t --units m --nosuffix -o +uuid,stripes,stripe_size,chunk_size'
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
        '/etc/oratab',
        '/var/opt/oracle/oratab',
    ],
}

# TBD - experimental
hpux_config = {
    'commands': {
        'uname_s': 'uname -s',
        'uname_rv': 'uname -rv',
        'model': 'model',
        'serial': 'getconf MACHINE_SERIAL',
        'machinfo': 'machinfo',
        'ioscan_disk': 'ioscan -funNC disk',
        'ioscan_hwpath': 'ioscan -m hwpath',
        'lanscan': 'lanscan',
        'netstat_in': 'netstat -in',
        'ps_ef': 'ps -ef',
        'df_p': 'df -P',
        'df_k': 'df -k',
        'df_n': 'df -n',
        'vgdisplay': 'vgdisplay',
    },
    'rootcommands': {
        'ioscan_proc': '/usr/sbin/ioscan -fnC processor',
        'pvdisplay': '/usr/sbin/pvdisplay',
        'lvdisplay': '/usr/sbin/lvdisplay',
    },
    'files': [
        '/etc/oratab',
    ],
}

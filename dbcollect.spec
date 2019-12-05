Name:		dbcollect
Summary:	Collect AWR/Statspack and system info
Version:	1.0.6
Release:	1%{?dtap}
License:	GPLv3+
Group:		Applications/Databases
Source0:	%{name}-%{version}.tbz2
Distribution:	Outrun Extras
BuildArch:	noarch

%description
This tool collects AWR reports for all normal database instances listed in /etc/oratab.
For this, sqlplus is called with @collect-awr to generate the AWRs.
Also collects cpuinfo, meminfo, and partition info from /proc.
The AWR files as well as the system info reports are placed in a ZIP file named
/tmp/<hostname>-collectawr.zip

%prep
%setup -q -n %{name}

%install
rm -rf %{buildroot}
install -m 0755 -d %{buildroot}/usr/bin
install -m 0755 -d %{buildroot}/usr/share/dbcollect/

cp -p  bin/*   %{buildroot}/usr/bin/
cp -pr share/* %{buildroot}/usr/share/dbcollect/

%files
%defattr(0755,root,root,755)
/usr/bin/*
/usr/share/dbcollect/*

Name:		dbcollect
Summary:	Collect AWR/Statspack and system info
Version:	1.2.3
Release:	1%{?dtap}
License:	GPLv3+
Group:		Applications/Databases
Source0:	%{name}-%{version}.tbz2
Distribution:	Outrun Extras
BuildArch:	noarch

%description
This tool collects AWR or Statspack reports for all normal database instances
listed in /etc/oratab. For this, sqlplus is called with @collect-awr or @collect-statspack
to generate the AWRs.
It also collects:
- SAR files
- System info via 'syscollect'
The AWR/SP files, SAR files as well as the system info are placed in a ZIP file named
/tmp/<hostname>-dbcollect.zip

%prep
%setup -q -n %{name}

%install
rm -rf %{buildroot}
install -m 0755 -d %{buildroot}/usr/bin
install -m 0755 -d %{buildroot}/usr/share/dbcollect/

cp -pr share/* %{buildroot}/usr/share/dbcollect/

ln -s /usr/share/dbcollect/syscollect %{buildroot}/usr/bin/syscollect
ln -s /usr/share/dbcollect/dbcollect %{buildroot}/usr/bin/dbcollect

%files
%defattr(0755,root,root,755)
/usr/bin/*
/usr/share/dbcollect/*

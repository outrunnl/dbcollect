Name:		dbcollect
Summary:	Collect AWR/Statspack and system info
Version:	%(python src/dbcollect/dbcollect.py -V | awk '/^Version/ {print $NF}')
Release:	1%{?dtap}
License:	GPLv3+
Group:		Applications/Databases
#Source0:	%{name}-%{version}.tbz2
Distribution:	Outrun Extras
BuildArch:	noarch

%description
This tool collects AWR or Statspack reports for all normal database instances
listed in oratab or detected otherwise.
It also collects:
- SAR files
- System info
The AWR/SP files, SAR files as well as the system info are placed in a ZIP file named
/tmp/dbcollect-<hostname>.zip

%prep
#setup -q -n %{name}

%install
rm -rf %{buildroot}
install -m 0755 -d %{buildroot}/usr/bin
install -m 0755 -d %{buildroot}/usr/share/dbcollect/

curl -fLl https://github.com/outrunnl/dbcollect/releases/download/v%{version}/dbcollect -o %{buildroot}/usr/bin/dbcollect

%files
%defattr(0755,root,root,755)
/usr/bin/*

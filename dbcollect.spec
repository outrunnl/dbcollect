Name:		dbcollect
Summary:	Collect AWR/Statspack and system info
Version:	1.4.7
Release:	1%{?dtap}
License:	GPLv3+
Group:		Applications/Databases
Source0:	%{name}-%{version}.tbz2
Distribution:	Outrun Extras
Requires:	python-argparse
BuildArch:	noarch

# Prevent compiling .py files
%define	__python	false

%description
This tool collects AWR or Statspack reports for all normal database instances
listed in oratab or detected otherwise.
It also collects:
- SAR files
- System info
The AWR/SP files, SAR files as well as the system info are placed in a ZIP file named
/tmp/dbcollect-<hostname>.zip

%prep
%setup -q -n %{name}

%install
rm -rf %{buildroot}
install -m 0755 -d %{buildroot}/usr/bin
install -m 0755 -d %{buildroot}/usr/share/dbcollect/

cp -pr dbcollect/* %{buildroot}/usr/share/dbcollect/
cp -p  bin/dbcollect %{buildroot}/usr/bin/

%files
%defattr(0755,root,root,755)
/usr/share/dbcollect
/usr/bin/dbcollect

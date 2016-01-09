%define name	book-publisher
%define version	1.0
%define release	1.dlts%{?dist}
%define dlibdir	/usr/local/dlib/%{name}

%if %{undefined __perl_provides}
%define __perl_provides /usr/lib/rpm/perl.prov
%endif

Summary:	Publish books to DLTS book site.
Name:		%{name}
Version:	%{version}
Release:	%{release}
License:	NYU DLTS
Vendor:		NYU DLTS (rasan@nyu.edu)
Group:		Applications/Publishing
URL:		https://github.com/rrasch/%{name}
BuildRoot:	%{_tmppath}/%{name}-root
BuildArch:	noarch
BuildRequires:	perl
BuildRequires:	subversion
Requires:	ImageMagick
Requires:	kakadu
Requires:	libtiff
%if 0%{?rhel}
Requires:	pdftk
%endif
Requires:	perl-Image-ExifTool
Requires:	perl-SOAP-Lite
Requires:	perl-DBD-MySQL
Requires:	php-cli
Requires:	poppler-utils
Requires:	tesseract

%description
%{summary}

%prep
rm -rf %{name}
# svn export %{url}/tags/%{version}  %{name}
# svn export %{url}/trunk %{name}
git clone %{url}.git %{name}
cd %{name}

EXCLUDE_MODULES=`find lib -name '*.pm' \
	| sed 's,^lib/,,' \
	| sed 's,\.pm$,,' \
	| sed 's,/,::,g' \
	| paste -sd '|'`
EXCLUDE_MODULES="$EXCLUDE_MODULES|MyConfig|MyLogger|WebService::Solr"

%define exclude_modules_file %{_builddir}/%{name}/exclude_modules.txt

(echo -e "MyConfig\nMyLogger\nWebService::Solr"; \
	find lib -name '*.pm') \
	| sed 's,^lib/,,' \
	| sed 's,\.pm$,,' \
	| sed 's,/,::,g' \
	| sed 's,^,perl\\(,' \
	| sed 's,$,\\),' \
	| sort \
	| paste -sd '|' > %exclude_modules_file

%define __provides_exclude %(cat %exclude_modules_file)
%define __requires_exclude %(cat %exclude_modules_file)

# Filter unwanted Provides:
cat <<EOF > %{name}-prov
#!/bin/sh
%{__perl_provides} $* | egrep -v "^perl\(($EXCLUDE_MODULES)\)"
EOF
%define __perl_provides %{_builddir}/%{name}/%{name}-prov
chmod +x %{__perl_provides}

# Filter unwanted Requires:
cat <<EOF > %{name}-req
#!/bin/sh
%{__perl_requires} $* | egrep -v "^perl\(($EXCLUDE_MODULES)\)"
EOF
%define __perl_requires %{_builddir}/%{name}/%{name}-req
chmod +x %{__perl_requires}

perl -pi -e 's,FindBin::Bin/lib,FindBin::Bin/../lib,' *.pl
perl -pi -e 's,dirname\(abs_path\(\$0\)\),"%{dlibdir}",' *.pl
perl -pi -e 's,./lib/simplehtmldom,../lib/simplehtmldom,' fix-hocr.php

%build

%install
rm -rf %{buildroot}
cd %{name}

mkdir -p -m 775 %{buildroot}%{dlibdir}

cp -r bin  %{buildroot}%{dlibdir}
cp -r conf %{buildroot}%{dlibdir}
cp -r doc  %{buildroot}%{dlibdir}
cp -r lib  %{buildroot}%{dlibdir}
cp *.pl *.sh *.php %{buildroot}%{dlibdir}/bin

find %{buildroot}%{dlibdir} -type d | xargs chmod 0775
find %{buildroot}%{dlibdir} -type f | xargs chmod 0664
chmod 0775 %{buildroot}%{dlibdir}/bin/*

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, dlib)
%dir %{dlibdir}
%config(noreplace) %{dlibdir}/conf
%{dlibdir}/bin
%{dlibdir}/doc
%{dlibdir}/lib

%changelog


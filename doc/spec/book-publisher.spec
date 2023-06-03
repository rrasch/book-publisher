%bcond_with langpacks

%define name	book-publisher
%define version	1.0.7
%define repourl	https://github.com/rrasch/%{name}
%define gitdate	%(date +"%Y%m%d")
%define commit	%(get-commit-id.sh %{repourl})
%define release	1.dlts.git.%{gitdate}.%{commit}%{?dist}
%define dlibdir	/usr/local/dlib/%{name}
%define liburl	https://github.com/rrasch/libpublishing

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
URL:		%{repourl}
BuildRoot:	%{_tmppath}/%{name}-root
BuildArch:	noarch
BuildRequires:	/usr/bin/perl
BuildRequires:	perl-generators
BuildRequires:	git
Requires:	hocr-tools
Requires:	ImageMagick
Requires:	kakadu
Requires:	libtiff
%if 0%{?fedora} >= 28 || 0%{?rhel} >= 8
Requires:	libtiff-tools
%endif
Requires:	ocrodjvu
Requires:	/usr/bin/pdftk
Requires:	perl-Image-ExifTool
Requires:	perl-SOAP-Lite
Requires:	perl-DBD-MySQL
Requires:	pdf2djvu
Requires:	php-cli
%if 0%{?fedora} >= 28 || 0%{?rhel} >= 8
Requires:	python3-countryinfo
Requires:	python3-geopy
Requires:	python3-lxml
Requires:	python3-pillow
Requires:	python3-pyyaml
Requires:	python3-redis
%endif
Requires:	poppler-utils >= 0.87.0
Requires:	qpdf
Requires:	tesseract
Requires:	tesseract-osd
Requires:	tesseract-langpack-ara
Requires:	tesseract-langpack-deu
Requires:	tesseract-langpack-fra
Requires:	tesseract-langpack-ita
Requires:	tesseract-langpack-kat
Requires:	tesseract-langpack-kat_old
%if %{with langpacks}
Requires:	tesseract-langpack-afr
Requires:	tesseract-langpack-amh
Requires:	tesseract-langpack-ara
Requires:	tesseract-langpack-asm
Requires:	tesseract-langpack-aze
Requires:	tesseract-langpack-aze_cyrl
Requires:	tesseract-langpack-bel
Requires:	tesseract-langpack-ben
Requires:	tesseract-langpack-bod
Requires:	tesseract-langpack-bos
Requires:	tesseract-langpack-bul
Requires:	tesseract-langpack-cat
Requires:	tesseract-langpack-ceb
Requires:	tesseract-langpack-ces
Requires:	tesseract-langpack-chi_sim
Requires:	tesseract-langpack-chi_tra
Requires:	tesseract-langpack-chr
Requires:	tesseract-langpack-cym
Requires:	tesseract-langpack-dan
Requires:	tesseract-langpack-dan_frak
Requires:	tesseract-langpack-deu
Requires:	tesseract-langpack-deu_frak
Requires:	tesseract-langpack-dzo
Requires:	tesseract-langpack-ell
Requires:	tesseract-langpack-enm
Requires:	tesseract-langpack-epo
Requires:	tesseract-langpack-equ
Requires:	tesseract-langpack-est
Requires:	tesseract-langpack-eus
Requires:	tesseract-langpack-fas
Requires:	tesseract-langpack-fin
Requires:	tesseract-langpack-fra
Requires:	tesseract-langpack-frk
Requires:	tesseract-langpack-frm
Requires:	tesseract-langpack-gle
Requires:	tesseract-langpack-glg
Requires:	tesseract-langpack-grc
Requires:	tesseract-langpack-guj
Requires:	tesseract-langpack-hat
Requires:	tesseract-langpack-heb
Requires:	tesseract-langpack-hin
Requires:	tesseract-langpack-hrv
Requires:	tesseract-langpack-hun
Requires:	tesseract-langpack-iku
Requires:	tesseract-langpack-ind
Requires:	tesseract-langpack-isl
Requires:	tesseract-langpack-ita
Requires:	tesseract-langpack-ita_old
Requires:	tesseract-langpack-jav
Requires:	tesseract-langpack-jpn
Requires:	tesseract-langpack-kan
Requires:	tesseract-langpack-kat
Requires:	tesseract-langpack-kat_old
Requires:	tesseract-langpack-kaz
Requires:	tesseract-langpack-khm
Requires:	tesseract-langpack-kir
Requires:	tesseract-langpack-kor
Requires:	tesseract-langpack-kur
Requires:	tesseract-langpack-lao
Requires:	tesseract-langpack-lat
Requires:	tesseract-langpack-lav
Requires:	tesseract-langpack-lit
Requires:	tesseract-langpack-mal
Requires:	tesseract-langpack-mar
Requires:	tesseract-langpack-mkd
Requires:	tesseract-langpack-mlt
Requires:	tesseract-langpack-msa
Requires:	tesseract-langpack-mya
Requires:	tesseract-langpack-nep
Requires:	tesseract-langpack-nld
Requires:	tesseract-langpack-nor
Requires:	tesseract-langpack-ori
Requires:	tesseract-langpack-pan
Requires:	tesseract-langpack-pol
Requires:	tesseract-langpack-por
Requires:	tesseract-langpack-pus
Requires:	tesseract-langpack-ron
Requires:	tesseract-langpack-rus
Requires:	tesseract-langpack-san
Requires:	tesseract-langpack-sin
Requires:	tesseract-langpack-slk
Requires:	tesseract-langpack-slk_frak
Requires:	tesseract-langpack-slv
Requires:	tesseract-langpack-spa
Requires:	tesseract-langpack-spa_old
Requires:	tesseract-langpack-sqi
Requires:	tesseract-langpack-srp
Requires:	tesseract-langpack-srp_latn
Requires:	tesseract-langpack-swa
Requires:	tesseract-langpack-swe
Requires:	tesseract-langpack-syr
Requires:	tesseract-langpack-tam
Requires:	tesseract-langpack-tel
Requires:	tesseract-langpack-tgk
Requires:	tesseract-langpack-tgl
Requires:	tesseract-langpack-tha
Requires:	tesseract-langpack-tir
Requires:	tesseract-langpack-tur
Requires:	tesseract-langpack-uig
Requires:	tesseract-langpack-ukr
Requires:	tesseract-langpack-urd
Requires:	tesseract-langpack-uzb
Requires:	tesseract-langpack-uzb_cyrl
Requires:	tesseract-langpack-vie
Requires:	tesseract-langpack-yid
%endif
# if 0{?rhel} >= 7
# Requires:	dlts-publishing-pyenv
# Requires:	natural-earth-map-data
# endif

%description
%{summary}

%prep
rm -rf %{name}
# svn export %{url}/tags/%{version}  %{name}
# svn export %{url}/trunk %{name}
git clone %{url}.git %{name}
cd %{name}
git clone %{liburl}.git lib
rm -rf .git lib/.git

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
# perl -pi -e 's,/etc/content-publishing/book,/usr/local/dlib/content_publishing/book/conf,' *.pl
perl -pi -e 's,./lib/simplehtmldom,../lib/simplehtmldom,' fix-hocr.php

# %if 0%{?rhel} >= 7
# perl -pi -e "s,#!/usr/bin/env python3,#!%{_bindir}/dlts-python," *.py
# %endif

%build

%install
rm -rf %{buildroot}
cd %{name}

mkdir -p -m 775 %{buildroot}%{dlibdir}

# cp -r bin  %{buildroot}%{dlibdir}
mkdir -p %{buildroot}%{dlibdir}/bin
cp -r conf %{buildroot}%{dlibdir}
cp -r doc  %{buildroot}%{dlibdir}
cp -r lib  %{buildroot}%{dlibdir}
cp *.pl *.sh *.php *.py %{buildroot}%{dlibdir}/bin

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


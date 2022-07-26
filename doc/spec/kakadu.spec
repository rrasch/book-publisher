%define major_version	v6_4_1
%define minor_version	01187N
%define real_version	%{major_version}-%{minor_version}

%ifarch x86_64
%define linux_version	Linux-x86-64-gcc
%else
%define linux_version	Linux-x86-32-gcc
%endif

%define _buildshell     /bin/bash

Name:		kakadu
Version:	6.4.1
Release:	1%{?dist}
Summary:	JPEG2000 toolkit
Group:		System Environment/Libraries
License:	Kakadu Non-Commercial
URL:		http://kakadusoftware.com
Source0:	%{real_version}.zip
Patch0:		kakadu-tiff.patch
Patch1:		kakadu-bool.patch
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildRequires:	libtiff-devel
%if 0%{?fedora} >= 35 || 0%{?rhel} >= 8
BuildRequires:	java-latest-openjdk-devel
%endif


%description
A comprehensive, heavily optimized, fully compliant software toolkit
for JPEG2000 developers.  Now with more extensive and convenient
support for Java native interfaces. Also now automatically builds
bindings for C# and Visual Basic programmers

Now with multi-threaded processing to fully utilize parallel
processing resources (multiple CPUs, multi-core CPUs or
hyperthreading). You can select the single-threaded processing model
from v5.0 and before, or a new multi-threaded processing model
(requires only a few extra lines of code in your application).

Kakadu provides a carefully engineered thread scheduler so once you
have created a multi-threaded environment and populated it with one
thread for each physical/virtual processor on your system, close to
100% utilization of all computational resources is typically
achieved.

Kakadu is a complete implementation of the JPEG2000 standard, Part
1, -- i.e., ISO/IEC 15444-1. This new image compression standard is
substantially more complex than the existing JPEG standard, both
from a computational and a conceptual perspective.

Kakadu also provides a comprehensive implementation for several of
the most useful features from Part 2 of the JPEG2000 standard,
including general multi-component transforms and arbitrary wavelet
transform kernels.

The Kakadu software framework provides a solid foundation for a
range of commercial and non-commercial applications. By making a
consistent and efficient implementation of the standard widely
available for both academic and commercial applications, our aim is
to encourage the widespread adoption of JPEG2000.


%prep
%setup -q -c
%patch0
%patch1


%build
%if 0%{?fedora} >= 35 || 0%{?rhel} >= 8
export JAVA_HOME=/usr/lib/jvm/java-openjdk
%else
export JAVA_HOME=/usr/java/latest
%endif
export PATH=$JAVA_HOME/bin:$PATH

pushd %{real_version}/make
make -f Makefile-%{linux_version}
popd

pushd java/kdu_jni
javac *.java
popd


%install
rm -rf $RPM_BUILD_ROOT

export JAVA_HOME=/usr/java/latest
export PATH=$JAVA_HOME/bin:$PATH

mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_libdir}
mkdir -p %{buildroot}%{_includedir}/%{name}
mkdir -p %{buildroot}%{_datadir}/java

pushd %{real_version}
install -m 0755 bin/%{linux_version}/*    %{buildroot}%{_bindir}
install -m 0755 lib/%{linux_version}/*.so %{buildroot}%{_libdir}
install -m 0644 lib/%{linux_version}/*.a  %{buildroot}%{_libdir}
install -m 0644 managed/all_includes/*.h  %{buildroot}%{_includedir}/%{name}
popd

pushd java
jar cvf %{buildroot}%{_datadir}/java/kakadu.jar kdu_jni
popd


%clean
rm -rf $RPM_BUILD_ROOT


%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig


%files 
%defattr(-,root,root,-)
%doc %{real_version}/*.txt %{real_version}/documentation/*
%doc %{real_version}/managed/*samples
%{_bindir}/*
%{_libdir}/*
%{_includedir}/*
%{_datadir}/java/*


%changelog
* Mon Jun 06 2011 Rasan Rasch <rasan@nyu.edu> - 6.4.1-1
- new build


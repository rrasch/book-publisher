%{!?license_num:%{error:license_num macro must be defined}}

%define version         8.5
%define version_und     %(echo %{version} | tr . _)
%define source_version  v%{version_und}-%{license_num}
%define linux_version   Linux-x86-64-gcc
%define java_home       /usr/lib/jvm/java-latest-openjdk

Name:           kakadu
Version:        %{version}
Release:        1.dlts%{?dist}
Summary:        JPEG2000 toolkit
Group:          System Environment/Libraries
License:        Kakadu Non-Commercial
URL:            http://kakadusoftware.com
Source0:        %{source_version}.zip
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildRequires:  libtiff-devel
BuildRequires:  java-latest-openjdk-devel


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
%setup -n %{source_version}


%build
export JAVA_HOME=%{java_home}
export PATH=$JAVA_HOME/bin:$PATH

pushd make
make -f Makefile-%{linux_version}
popd

pushd ../java/kdu_jni
javac *.java
popd

%install
rm -rf $RPM_BUILD_ROOT

export JAVA_HOME=%{java_home}
export PATH=$JAVA_HOME/bin:$PATH

mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_libdir}
mkdir -p %{buildroot}%{_includedir}/%{name}
mkdir -p %{buildroot}%{_datadir}/java

install -m 0755 bin/%{linux_version}/*    %{buildroot}%{_bindir}
install -m 0755 lib/%{linux_version}/*.so %{buildroot}%{_libdir}
install -m 0644 lib/%{linux_version}/*.a  %{buildroot}%{_libdir}
install -m 0644 managed/all_includes/*.h  %{buildroot}%{_includedir}/%{name}

pushd ../java
jar cvf %{buildroot}%{_datadir}/java/kakadu.jar kdu_jni
popd

chmod 0644 *.txt
find documentation -type f -exec chmod 644 {} \;
find managed/*samples -type f -exec chmod 644 {} \;

%clean
rm -rf $RPM_BUILD_ROOT


%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig


%files 
%defattr(-,root,root,-)
%doc *.txt
%doc documentation
%doc managed/*samples
%{_bindir}/*
%{_libdir}/*
%{_includedir}/*
%{_datadir}/java/*


%changelog
* Thu Mar 12 2026 Rasan Rasch <rasan@nyu.edu> - 8.5-1
- Update to 8.5

* Mon Jun 06 2011 Rasan Rasch <rasan@nyu.edu> - 6.4.1-1
- new build

%define vermaj 18
%define vermin 3-beta
%define debug_package %{nil}

Name:           polo
Version:        %{vermaj}
Release:        3_beta%{?dist}
Summary:        Advanced file manager for Linux written in Vala.

License:        LGPLv3+
URL:            https://github.com/teejee2008/%{name}
Source0:        https://github.com/teejee2008/%{name}/archive/v%{vermaj}.%{vermin}.tar.gz

BuildRequires:  vala, vte291-devel, libgee-devel, json-glib-devel, libxml2-devel, chrpath, gettext
Requires:       libgee, vte291, json-glib, libxml2, libmediainfo, rsync, pv, p7zip, p7zip-plugins, tar, gzip
Requires:	bzip2, xz, fish, qemu-kvm, qemu-img, gvfs, rclone, libsoup, gvfs-afc, gvfs-afp, gvfs-goa
Requires:	gvfs-mtp, gvfs-nfs, gvfs-fuse, gvfs-fuse, gvfs-gphoto2 gvfs-archive, gvfs-smb

%description
Advanced file manager for Linux written in Vala. Supports multiple panes (single, dual, quad)
with multiple tabs in each pane. Supports archive creation, extraction and browsing. Support 
for cloud storage; running and managing KVM images, modifying PDF documents and image files, 
booting ISO files in KVM, and writing ISO files to USB drives.

%prep
%autosetup -n %{name}-%{vermaj}.%{vermin}

%build
make

%install
%make_install
chrpath --delete %{buildroot}%{_bindir}/polo-gtk
rm %{buildroot}%{_bindir}/polo-uninstall

%files
%{_bindir}/gtk3-version-polo
%{_bindir}/polo-gtk
%{_datarootdir}/applications/polo-gtk.desktop
%{_datarootdir}/appdata/polo-gtk.appdata.xml
%{_datarootdir}/locale/**/LC_MESSAGES/polo.mo
%{_datarootdir}/pixmaps/polo.png
%{_datarootdir}/polo/*


%changelog
* Fri Feb 23 2018 <grturner@5x5code.com> 18-2beta
- Fixed error with dependency - gvfs-backed
- see https://github.com/teejee2008/polo/issues/171
* Tue Jan 30 2018 <grturner@5x5code.com> 18-1beta
- Initial packaging

SHELL=/bin/bash
CFLAGS=--std=c99

prefix=/usr
bindir=$(prefix)/bin
sharedir=$(prefix)/share
localedir=$(sharedir)/locale
launcherdir=$(sharedir)/applications
mandir=$(sharedir)/man
man1dir=$(mandir)/man1

app_name=polo
app_fullname='Polo'

# vte -----------------------------

vte_symbol = -D VTE_291
vte_version=$(shell { (pkg-config --modversion vte-2.91 | cut -d. -f2); } )

ifeq ($(shell { test ${vte_version} -lt 52 ; echo $$? ; } ), 0)
vte_symbol=$(shell echo '-D VTE_291_OLD')
else
vte_symbol=$(shell echo '-D VTE_291')
endif

# gtk3 -----------------------------------------------------------------

gtk3_version=$(shell { (pkg-config --modversion gtk+-3.0 | cut -d. -f2); } )

ifeq ($(shell { test ${gtk3_version} -gt 17 ; echo $$? ; } ), 0)
gtk3_symbol=$(shell { echo '-D GTK3_18'; } )
else
gtk3_symbol=$(shell { echo ''; } )
endif

# symbols --------------------------

define_symbols=$(shell { echo "${vte_symbol} ${gtk3_symbol}"; } )

all: app-gtk app-translations app-util-disk app-util-gtk3 

app-gtk:

	#polo-gtk
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' \
		--Xcc="-lm" ${define_symbols} --Xcc="-O3" --thread \
		Common/Main.vala \
		Gtk/*.vala \
		Utility/*.vala \
		Utility/Gtk/*.vala \
		-o "${app_name}-gtk" \
		--target-glib 2.32 --pkg glib-2.0 \
		--pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 \
		--pkg gee-0.8 --pkg json-glib-1.0 --pkg libxml-2.0 \
		--pkg vte-2.91 \
		--pkg gdk-x11-3.0

app-util-gtk3:
	valac "polo-gtk3-helper.vala" -o polo-gtk3-helper --pkg gtk+-3.0

app-util-disk:
	valac --Xcc="-lm" -X -D'GETTEXT_PACKAGE="${app_name}"' \
		"polo-disk.vala" Console/*.vala -o polo-disk --pkg posix --pkg gio-unix-2.0 --pkg gee-0.8

app-translations:

	# update translation template
	xgettext --language=C --keyword=_ \
		--copyright-holder='Tony George (teejeetech@gmail.com)' \
		--package-name='${app_name}' \
		--package-version='1.6' \
		--msgid-bugs-address='teejeetech@gmail.com' \
		--escape \
		--sort-output \
		--from-code=UTF-8 \
		-o ../${app_name}.pot \
		Common/*.vala \
		Gtk/*.vala \
		Utility/*.vala \
		Utility/Gtk/*.vala

	# update translation files
	for lang in de nl fr; do \
		msgmerge --update -v ../po/${app_name}-$$lang.po ../${app_name}.pot ; \
	done
	
	# am ar az bg ca cs da de el en_GB es et eu fr he hi hr hu ia id is it ko lt nb ne nl pl pt pt_BR ro ru sk sr sv tr uk vi zh_CN
		
clean:
	rm -rfv ../release/{source,i386,amd64,armel,armhf}
	rm -rfv ../release/*.{run,deb}
	rm -rfv *.c *.o *.mo
	rm -fv ${app_name}-gtk ${app_name}-gtk3-helper ${app_name}-disk

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/${app_name}"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps"
	mkdir -p "$(DESTDIR)$(sharedir)/appdata"
	mkdir -p "$(DESTDIR)/var/log/polo"
	
	#binary
	install -m 0755 ${app_name}-gtk "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-gtk3-helper "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-disk "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-uninstall "$(DESTDIR)$(bindir)"

	#shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${app_name}" ./share/${app_name}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${app_name}/*
	chmod a+x $(DESTDIR)$(sharedir)/${app_name}/files/gtk-theme/install-gtk-theme

	#launcher
	install -m 0644 ${app_name}-gtk.desktop "$(DESTDIR)$(launcherdir)"

	#app icon
	install -m 0755 ./share/pixmaps/${app_name}.png "$(DESTDIR)$(sharedir)/pixmaps/"

	# appdata
	install -m 0755 ../debian/${app_name}-gtk.appdata.xml "$(DESTDIR)$(sharedir)/appdata"

	# translations
	for lang in de nl fr; do \
		mkdir -p "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-$$lang.po ; \
	done
	
uninstall:

	#binary
	rm -f "$(DESTDIR)$(bindir)/${app_name}-gtk"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-gtk3-helper"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-disk"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-uninstall"

	#shared files
	rm -rf "$(DESTDIR)$(sharedir)/${app_name}"

	#launcher
	rm -f "$(DESTDIR)$(launcherdir)/${app_name}-gtk.desktop"

	#app icon
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${app_name}.png"

	# appdata
	rm -f "$(DESTDIR)$(sharedir)/appdata/${app_name}-gtk.appdata.xml"

	#translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${app_name}.mo

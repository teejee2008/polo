all:
	cd src; make all

app-gtk:
	cd src; make app-gtk

app-translations:
	cd src; make app-translations

app-util-gtk3:
	cd src; make app-util-gtk3

app-util-disk:
	cd src; make app-util-disk
	
clean:
	cd src; make clean

install:
	cd src; make install
	
uninstall:
	cd src; make uninstall

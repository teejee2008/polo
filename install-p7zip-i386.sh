#!/bin/bash

cd /tmp

wget http://launchpadlibrarian.net/279142192/p7zip_16.02+dfsg-1_i386.deb http://launchpadlibrarian.net/279142191/p7zip-full_16.02+dfsg-1_i386.deb http://launchpadlibrarian.net/279142173/p7zip-rar_16.02-1_i386.deb

sudo apt-get remove p7zip{,-full,-rar}

sudo dpkg -i p7zip_16.02+dfsg-1_i386.deb p7zip-full_16.02+dfsg-1_i386.deb p7zip-rar_16.02-1_i386.deb

echo 'done'

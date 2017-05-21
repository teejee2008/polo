#!/bin/bash

cd /tmp

wget http://launchpadlibrarian.net/279142125/p7zip_16.02+dfsg-1_amd64.deb http://launchpadlibrarian.net/279142124/p7zip-full_16.02+dfsg-1_amd64.deb http://launchpadlibrarian.net/279142120/p7zip-rar_16.02-1_amd64.deb

sudo apt-get remove p7zip{,-full,-rar}

sudo dpkg -i p7zip_16.02+dfsg-1_amd64.deb p7zip-full_16.02+dfsg-1_amd64.deb p7zip-rar_16.02-1_amd64.deb

echo 'done'


#!/bin/bash

tempDir=$(mktemp -d)
cd $tempDir
echo "Using tempdir: $tempDir"

if [ $(uname -m) == 'x86_64' ]; then
	arch="amd64"
	echo "Arch: 64-bit"
else
	arch="386"
	echo "Arch: 32-bit"
fi

zipName="rclone-current-linux-$arch"
zipFile="$zipName.zip"

echo ""
echo "---------------------------------------------------------------"
echo "Downloading $zipFile"
echo ""

wget "https://downloads.rclone.org/$zipFile"
if [ $? -ne 0 ]; then echo "Error"; exit 1; fi

unzip $zipFile
if [ $? -ne 0 ]; then echo "Error"; exit 1; fi

cd rclone-*-linux-$arch
if [ $? -ne 0 ]; then echo "Error"; exit 1; fi

echo ""
echo "---------------------------------------------------------------"
echo "Installing binaries"
echo ""
sudo cp rclone /usr/bin/
sudo chown root:root /usr/bin/rclone
sudo chmod 755 /usr/bin/rclone

echo ""
echo "---------------------------------------------------------------"
echo "Install Manpage"
echo ""
sudo mkdir -p /usr/local/share/man/man1
sudo cp rclone.1 /usr/local/share/man/man1/
sudo mandb 


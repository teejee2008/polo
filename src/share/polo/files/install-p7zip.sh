#!/bin/bash

tempDir=$(mktemp -d)
cd $tempDir
echo "Using tempdir: $tempDir"

if [ $(uname -m) == 'x86_64' ]; then
	arch="amd64"
	echo "Arch: 64-bit"
else
	arch="i386"
	echo "Arch: 32-bit"
fi

runName="p7zip-v16.02-$arch"
runFile="$runName.run"

echo ""
echo "---------------------------------------------------------------"
echo "Downloading $runFile"
echo ""
wget "https://github.com/teejee2008/p7zip-installer/releases/download/v16.02/$runFile"
if [ $? -ne 0 ]; then echo "Error"; exit 1; fi

echo ""
echo "---------------------------------------------------------------"
echo "Installing binaries"
echo ""
sh $runFile
if [ $? -ne 0 ]; then echo "Error"; exit 1; fi


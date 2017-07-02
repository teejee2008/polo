#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

app_name=$(cat app_name)
pkg_name=$(cat pkg_name)

# build debs
sh build-deb.sh

cd installer

for arch in i386 amd64
do

rm -rfv ${arch}/files
mkdir -pv ${arch}/files

echo ""
echo "=========================================================================="
echo " build-installers.sh : $arch"
echo "=========================================================================="
echo ""

dpkg-deb -x ${arch}/${app_name}*.deb ${arch}/files

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

rm -rfv ${arch}/${app_name}*.* # remove extra files
cp -pv --no-preserve=ownership ./sanity.config ./${arch}/sanity.config
sanity --generate --base-path ./${arch} --out-path . --arch ${arch}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

done


cd "$backup"

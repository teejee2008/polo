#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

. ./BUILD_CONFIG

rm -vf installer/*.run
rm -vf installer/*.deb

# build debs
sh build-deb.sh


for arch in i386 amd64
do

rm -rfv release/${arch}/files
mkdir -pv release/${arch}/files

echo ""
echo "=========================================================================="
echo " build-installers.sh : $arch"
echo "=========================================================================="
echo ""

dpkg-deb -x release/${pkg_name}-v${pkg_version}-${arch}.deb release/${arch}/files

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

cp -pv --no-preserve=ownership release/sanity.config release/${arch}/sanity.config
sanity --generate --base-path release/${arch} --out-path release --arch ${arch}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

mv -v release/*${arch}.run release/${pkg_name}-v${pkg_version}-${arch}.run 

echo "--------------------------------------------------------------------------"

done

cp -vf release/*.run ../PACKAGES/
cp -vf release/*.deb ../PACKAGES/

cd "$backup"

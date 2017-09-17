#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

. ./BUILD_CONFIG

tgz="../../pbuilder/"
dsc="../../builds/${pkg_name}*.dsc"
libs="../../libs"

sh build-source.sh

cd installer

for arch in i386 amd64
do

echo ""
echo "=========================================================================="
echo " build-deb.sh : $arch"
echo "=========================================================================="
echo ""

rm -rfv ${arch}
mkdir -pv ${arch}

echo "-------------------------------------------------------------------------"

sudo pbuilder --build --buildresult ${arch} --basetgz "${tgz}base-${arch}.tgz" ${dsc}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

cp -pv --no-preserve=ownership ./${arch}/${pkg_name}*.deb ./${pkg_name}-v${pkg_version}-${arch}.deb 

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

done

cd "$backup"

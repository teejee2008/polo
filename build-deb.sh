#!/bin/bash

app_name=$(cat app_name)
pkg_name=$(cat pkg_name)

tgz="../../pbuilder/"
dsc="../../builds/${app_name}*.dsc"
libs="../../libs"

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

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

cp -pv --no-preserve=ownership ./${arch}/${app_name}*.deb ./${app_name}-${arch}.deb 

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

done

cd "$backup"

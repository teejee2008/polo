#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

oldname=$1
newname=$2

grep -R $oldname
echo "==========================================================================="

find . -type f -print0 | xargs -0 sed -i "s/$oldname/$newname/g"

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"
	echo "Failed"
	exit 1
fi

echo "==========================================================================="

grep -R $newname

echo "==========================================================================="
find . -type d -print0 | xargs -0 rename "s/$oldname/$newname/g"
find . -type f -print0 | xargs -0 rename "s/$oldname/$newname/g"

cd "$backup"

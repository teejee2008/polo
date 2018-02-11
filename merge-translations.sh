#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

. ./BUILD_CONFIG

languages="am ar az bg ca cs da de el en_GB es et eu fi fr he hi hr hu ia id is it ko lt nb ne nl pl pt pt_BR ro ru sk sr sv tr uk vi zh_CN"

echo ""
echo "=========================================================================="
echo " Update PO files in po/ with translations placed in po-temp/"
echo "=========================================================================="
echo ""

for lang in $languages; do
	if [ -e "po-temp/${app_name}-$lang.po" ]; then
		# remove headers in po-temp/*.po so that msgcat does not create malformed headers
		sed -i '/^#/d' po-temp/${app_name}-$lang.po
		msgcat -o po/${app_name}-$lang.po po-temp/${app_name}-$lang.po po/${app_name}-$lang.po
		sed -i '/#-#-#-#-#/d' po/${app_name}-$lang.po
		sed -i '/#, fuzzy/d' po/${app_name}-$lang.po
	fi
done

echo ""
echo "=========================================================================="
echo " Update PO files in po/ with latest POT file"
echo "=========================================================================="
echo ""

for lang in $languages; do
	if [ -e "po-temp/${app_name}-$lang.po" ]; then
		msgmerge --update -v po/${app_name}-$lang.po ${app_name}.pot
	fi
done

cd "$backup"

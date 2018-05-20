#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

sudo cp -vf "$SCRIPTPATH/85-no-automount.rules" /etc/udev/rules.d/85-no-automount.rules

if [ -x "$(command -v systemctl)" ]; then
  sudo systemctl restart udisks2.service
fi

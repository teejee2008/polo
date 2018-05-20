#!/bin/bash

sudo rm -vf /etc/udev/rules.d/85-no-automount.rules

if [ -x "$(command -v systemctl)" ]; then
	sudo systemctl restart udisks2.service
fi


#!/bin/bash
DIR="$(cd "$(dirname $0)" && pwd)"
cd $DIR
if [ "$DIR" !=  "/usr/share/plymouth/themes/win10" ];then
mkdir -p /usr/share/plymouth/themes/win10
cp * /usr/share/plymouth/themes/win10
fi
cd /usr/share/plymouth/themes/win10
chown root:root *
chmod 644 *
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/win10/win10.plymouth 100
update-alternatives --set default.plymouth /usr/share/plymouth/themes/win10/win10.plymouth #here, choose the number of the theme you want to use then hit enter
update-initramfs -u

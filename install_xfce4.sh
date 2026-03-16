#!/bin/bash
#
#  This script will install LXQt from alienbob repo.
#  Change SLACKVER for that is installed on your pc.
#
#  Run as root.
#
#  AUTHOR: Iuri Freire
#  EMAIL : iuricostafreire at gmail dot com
#  GITHUB: github.com/ifreire
#  DATE  : 2020-05-22
#  Modify for DE by demo4him
#  date: 2026-03-16
#  source: https://slackware.uk/salix/

SLACKVER=15.0
ARCH=$(uname -m)

mkdir ~/.xfce4pkgs
cd ~/.xfce4pkgs

lftp -c "open https://slackware.uk/salix/x86_64/ ; mirror --exclude source/ --include salix/ xfce4.20-15.0 -c -e -v"
cd ~/.xfce4pkgs/xfce4.20-15.0/
mv ~/.xfce4pkgs/xfce4.20-15.0/salix/l/* ~/.xfce4pkgs/xfce4.20-15.0/
mv ~/.xfce4pkgs/xfce4.20-15.0/salix/x/* ~/.xfce4pkgs/xfce4.20-15.0/
mv ~/.xfce4pkgs/xfce4.20-15.0/salix/xfce/* ~/.xfce4pkgs/xfce4.20-15.0/
cd ~/.xfce4pkgs/xfce4.20-15.0/
upgradepkg --reinstall --install-new *.t?z
#rm -rf ~/.xfce4pkgs
echo ALL DONE!

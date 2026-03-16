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
#  Modify for LXDE by demo4him
#  date: 2026-03-16
#  source: https://ponce.cc/

SLACKVER=15.0
ARCH=$(uname -m)

mkdir ~/.lxdepkgs
cd ~/.lxdepkgs

lftp -c "open http://ponce.cc/slackware/slackware64-15.0/; mirror lxde -c -e -v"

cd lxde

upgradepkg --reinstall --install-new *.t?z

#rm -rf ~/.lxdepkgs
echo ALL DONE!

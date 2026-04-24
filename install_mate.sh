#!/bin/bash
#
#  This script will install MATE Desktop from slackware.uk repo.
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
#  source: https://slackware.uk/msb/

SLACKVER=15.0
ARCH=$(uname -m)

mkdir ~/.msbpkgs
cd ~/.msbpkgs

lftp -c "open https://slackware.uk/msb/15.0/latest/ ; mirror x86_64 -c -e -v"
cd ~/.msbpkgs/x86_64/
mv ~/.msbpkgs/x86_64/base/* ~/.msbpkgs/x86_64/
mv ~/.msbpkgs/x86_64/deps/* ~/.msbpkgs/x86_64/
mv ~/.msbpkgs/x86_64/extra/* ~/.msbpkgs/x86_64/
cd ~/.msbpkgs/x86_64/
upgradepkg --reinstall --install-new *.t?z
rm -rf ~/.msbpkgs
echo ALL DONE!

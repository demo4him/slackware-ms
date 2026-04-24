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
#  source: https://slackware.uk/msb/current

SLACKVER=15-current
ARCH=$(uname -m)

mkdir ~/.msbpkgs-current
cd ~/.msbpkgs-current

lftp -c "open https://slackware.uk/msb/current/latest/ ; mirror x86_64 -c -e -v"
cd ~/.msbpkgs-current/x86_64/
mv ~/.msbpkgs-current/x86_64/base/* ~/.msbpkgs-current/x86_64/
mv ~/.msbpkgs-current/x86_64/deps/* ~/.msbpkgs-current/x86_64/
mv ~/.msbpkgs-current/x86_64/extra/* ~/.msbpkgs-current/x86_64/
cd ~/.msbpkgs-current/x86_64/
upgradepkg --reinstall --install-new *.t?z
rm -rf ~/.msbpkgs-current
echo ALL DONE!

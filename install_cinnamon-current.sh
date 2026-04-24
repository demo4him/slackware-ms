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
#  Modify by demo4him
#  date: 2026-03-16
#  source: https://slackware.uk/csb/current

SLACKVER=15-current
ARCH=$(uname -m)

mkdir ~/.csbpkgs-current
cd ~/.csbpkgs-current

lftp -c "open https://slackware.uk/csb/current/; mirror x86_64 -c -e -v"

cd x86_64

upgradepkg --reinstall --install-new *.t?z

rm -rf ~/.csbpkgs-current
echo ALL DONE!

#!/bin/sh
echo ""
echo '  Before running this script type "dhcpcd" to get internet up and running'
sleep 4
echo ""
echo ""

cd /
sleep 1

# test for /tag directory first if not then create it
if [ -d /tag ] ;
then
cd /tag ;

elif [ ! -d /tag ] ;
then
mkdir /tag ;
cd /tag ;
else
echo "  /tag directory not found check your location" && sleep 4 && exit;	
fi

cd /tag

echo "  Current directory is: $(pwd)"
echo ""
echo "  Now downloding tagfiles"
echo ""
sleep 6

wget  raw.githubusercontent.com/demo4him/slackware-ms/refs/heads/main/tagfiles.tar.xz

echo ""
echo "  expanding tagfiles.tar.xz"
sleep 4

tar -xf tagfiles.tar.xz 

sleep 2

rm tagfiles.tar.xz
sleep 2

cd / || exit
echo "" 
echo "  Tag files expanded to /tag/tagfiles sub directory"
echo ""
sleep 5
tree /tag || ls -R /tag
sleep 6
echo ""
sleep 2
cd /
echo "  Current directory is: $(pwd)"
sleep 3
echo ""
echo '  After this script exits type "cd /" to return to / and partition the'
echo '  target drives with cfdisk'
echo ""
echo '  Then run "setup" to select your "Target" and "Source"'
echo ""
echo '  For "Source" select your "Slackware64-15.0-install-dvd.iso"'
echo ""
sleep 8
echo '  After selection of the source media select the required directories'
echo '  of the Package tree you wish to install'
echo ""
sleep 8
echo '  Finally define the path to your tag files'
echo '  In "Select Prompting Mode" select "tagpath"'
echo ""
sleep 8
echo '  For "Provide a Custom Path to your tagfiles" type'
echo '  "/tag/tagfiles" (without quotes) and select "OK"'
sleep 3
echo ""
echo '  Installation of packages will then start' 
sleep 10
echo ""
echo '  "Important - do not use Alien Bobs slackware64-current-mini-install.iso'
echo '  to do a net-install of Slackware-15.0"'
echo ""
echo '  The slackware-current-mini-install.iso is incompatible with' 
echo '  Slackware-15.0 and therefore suitable for net-installs'
echo '  of Slackware-current only'
echo ""
echo '  If you want to do a net-install of Slackware-15 either use a'
echo '  slackware64-15.0-install-dvd.iso disk or make a custom'
echo '  slackware64-15.0-mini-install.iso'
echo ''
exit


#!/bin/sh
echo ""
echo '  Before running this script type "dhcpcd" to get internet up and running'
sleep 4
echo ""
echo "  Current directory is $(pwd)"
echo ""
echo "  Creating tag file directories in /tag"
echo ""
sleep 4

# edit the directory names into the array list for i so 
# your required tag files get downloaded by wget
# the full directory list avaliable is "a ap d k l n t x xap" 
# the following "a ap l n x" is the bare minumum for networking and X.

for i in a ap l n x ; do
	mkdir -p /tag/"$i" && wget -P /tag/"$i" raw.githubusercontent.com/demo4him/slackware-ms/refs/heads/main/tagfiles/"$i"/tagfile ;
done ;
sleep 1
cd / || exit
echo "" 
echo "  Tag files downloaded to /tag sub directories"
echo ""
tree /tag || ls -R /tag
sleep 6
echo ""
echo "  Current directory is: $(pwd)"
echo ""
echo '  After script exits type "cd /" to return to / and partition the target drives'
echo '  Then run "setup" to select your "Target" and "Source"'
echo ""
echo '  In "Source" select either "DVD iso" or "Install from ftp/http server"'
echo '  If ftp/http install selected for the server URL type "slackware.uk"'
echo '  For the source directory type "/slackware/slackware64-15.0/slackware"'
echo ""
echo '  In "Download Result" if "Packages.txt is available" select "No"'
echo '  then select the required directories of the Package tree'
echo ""
echo '  Finally define the path to your tag files'
echo '  In "Select Prompting Mode" select "tagpath"'
echo '  For "Provide a Custom Path to your tagfiles" type "/tag" and select "OK"'
echo '  Installation of packages will then start' 

exit


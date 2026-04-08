#!/bin/sh

#sudo mkdir /mnt/tmp
sudo mount /dev/sdb1 /mnt/tmp
sudo rsync -avx /home/ /mnt/tmp
sudo mount /dev/sdb1 /home
sudo umount /home
sudo rm -rf /home/*
echo "/dev/sdb1        /home            ext4        defaults         1   2" >> /etc/fstab
echo "Reboot Slackware!"

﻿#!/bin/bash

# Pre-requisites
# Install linux vm with attached data disks
# Script based on 4x Data disks


Install_step1()
{
# Enable swap file on the linux machine through azure agent file waagent.conf and disable selinux using the ex search replace editor

ex -s +%s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g +%p +x /etc/waagent.conf
ex -s +%s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=5120/g +%p +x /etc/waagent.conf
ex -s +%s/SELINUX=enforcing/SELINUX=disabled/g +%p +x /etc/selinux/config
echo 0 > /selinux/enforce
}

Install_step2()
{
#create a var listing available disks to partition
#hdd=$(find /dev/sd* ! -path "/dev/sda*" ! -path "/dev/sdb*")
for i in $hdd;do
echo "n
p
1


t
fd
w
"|fdisk $i;done

# Create a directory which you want to mount to the new disk. mkdir /data_disk
mkdir /data_disk
# Change Permissions
chmod 755 /data_disk
}

#using the find command we search for available disks to raid. using ! to exclude wilcard path sda and sdb. 
#We also then check the hdd list for *1* which would indicate existing partition and log. if not we call a function to raid available disks.

Install_step2a()
{
hdd=$(find /dev/sd* ! -path "/dev/sda*" ! -path "/dev/sdb*")
#if [[ $hdd == *1* ]] && echo "It's there" || echo "Couldn't find"
[[ $hdd == *1* ]] && echo "Cannot use. It contains existing partition!" 1>&2 >./mdadm.log || Install_step2
}

Install_step3()
{
#count available devicees to raid
devicecount=$(find /dev/sd*1 ! -path "/dev/sda*" ! -path "/dev/sdb*" | wc -l)

#list available devices to raid
raiddevices=$(find /dev/sd*1 ! -path "/dev/sda*" ! -path "/dev/sdb*")

# install mdam

yum -y install mdadm

# Create the raid device using 4 data disks- DataRaid

mdadm --create /dev/md127 --level 0 --raid-devices $devicecount  $raiddevices

# Create the file system on the new RAID device

mkfs.xfs /dev/md127
}

Install_step4()
{
UUID=`lsblk -no UUID /dev/md127`
until [ -n "$UUID" ]; do 
sleep 30s
UUID=`lsblk -no UUID /dev/md127`; 
done
sed -i:bak "/UUID/a\UUID=$UUID  /data_disk  xfs  defaults,noatime  0  2" /etc/fstab
mount -a
}

Install_step5()
{
# Install Mongo

# Create MongoDB repo

# Pre version 3.2

# echo '
# [mongodb-org-3.0]
# name=MongoDb Repository
# baseurl=http://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.0/x86_64/
# gpgcheck=0
# enabled=1' > /etc/yum.repos.d/mongodb-org-3.0.repo

# 3.2 and later

echo '[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc' > /etc/yum.repos.d/mongodb-org-3.2.repo

# 3.4 and later

echo '[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc' > /etc/yum.repos.d/mongodb-org-3.4.repo

# Install MongoDB

yum install -y mongodb-org

# Exclude MongoDB from /etc/yum.conf to avoid unintended upgrades of MongoDB
# three options, either place after last line or after specific text pattern (this you must know and hope it does not change) 
# or  insert after first blank line (must know your file current structure)
# ref http://www.linuxquestions.org/questions/programming-9/insert-line-on-match-only-once-with-sed-657764/

# append after last line
# sed -i:bak '$ a\exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools' /etc/yum.conf 

# append after PATTERN /distroverpkg=centos-release/ found
# sed -i:bak '/distroverpkg=centos-release/a\exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools' /etc/yum.conf 

#  inserting above first open line
 
sed -i:bak '1,/^$/ {/^$/i\
exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools
}' /etc/yum.conf

# Change the mongod.conf file to use yaml startup script with custom config
# delete all file content

ex -s +%d +%p +x /etc/mongod.conf

# insert yaml config 

echo 'systemLog:
   destination: file
   path: "/data_disk/mongo/logs/mongod.log"
   logAppend: true
   logRotate: rename
storage:
   dbPath: "/data_disk/mongo/data"
   engine: wiredTiger
   directoryPerDB: true
   journal:
      enabled: true
processManagement:
   fork: true
   pidFilePath: "/var/run/mongodb/mongod.pid"
net:
   port: 27017
replication:
   replSetName: "rs0"' > /etc/mongod.conf

# Create Mongo directories

mkdir /data_disk/mongo
mkdir /data_disk/mongo/logs
mkdir /data_disk/mongo/data
mkdir /data_disk/mongo/backups
mkdir /data_disk/mongo/backups/mongodumps
mkdir /data_disk/mongo/backups/mongoexports

# change ownership and group

chown -R mongod:mongod /data_disk
chown -R mongod:mongod /data_disk/mongo
chown -R mongod:mongod /data_disk/mongo/logs
chown -R mongod:mongod /data_disk/mongo/data
chown -R mongod:mongod /data_disk/mongo/backups
chown -R mongod:mongod /data_disk/mongo/backups/mongodumps
chown -R mongod:mongod /data_disk/mongo/backups/mongoexports

# setup log rotation by using linux cron job to run bash script
# create a scripts folder
mkdir /etc/scripts/

# first create your bash script.
# https://disqus.com/home/discussion/mongodb/logging_mongodb_10gen_confluence/
 
echo '#!/bin/bash

# This script below will rename the mongod log file with the date appended and open a new log file;
# we will then search for renamed log files older than 5 days and zip --removed this step, created new cron job
# maintenance- we will then find renamed files older than 31 days and delete --removed this step, created new cron job

#/bin/kill -SIGUSR1 `cat /data_disk/mongo/data/mongod.lock 2> /dev/null`
mongo --eval "db.getMongo().getDB(\"admin\").runCommand(\"logRotate\")";
#find /data_disk/mongo/logs/mongod.log.* -mtime +5 -execdir zip '{}'.zip '{}' -m -x *.zip \;
#find /data_disk/mongo/logs/mongod.log.* -mtime +31 -exec rm {} \;' > /etc/scripts/mongologrotation.sh

cat /etc/scripts/mongologrotation.sh

# now create the cron job to run the log rotation bash script /etc/scripts/mongologrotation.sh
# append after last line

echo '5 5 * * * root /etc/scripts/mongologrotation.sh' >> /etc/crontab
#echo '5 0 * * * /etc/scripts/mongologrotation.sh'>/etc/scripts/mongologrotation.txt
chmod 755 /etc/scripts/mongologrotation.sh
#chmod 755 mongologrotation.txt
#crontab /etc/scripts/mongologrotation.txt
#crontab -l

echo '#!/bin/bash

# This script will search for renamed log files older than x- days and zip
# maintenance- we will then find renamed files older than 31 days and delete

#/bin/kill -SIGUSR1 `cat /data_disk/mongo/data/mongod.lock 2> /dev/null`
#mongo --eval "db.getMongo().getDB(\"admin\").runCommand(\"logRotate\")";
find /data_disk/mongo/logs/mongod.log.* -mtime +5 -execdir zip '{}'.zip '{}' -m -x *.zip \;
find /data_disk/mongo/logs/mongod.log.* -mtime +31 -exec rm {} \;' > /etc/scripts/mongologcleanup.sh

cat /etc/scripts/mongologcleanup.sh

# now create the cron job to run the log cleanup bash script /etc/scripts/mongologcleanup.sh
# append after last line

echo '6 5 * * * root /etc/scripts/mongologcleanup.sh' >> /etc/crontab
#echo '5 0 * * * /etc/scripts/mongologcleanup.sh'>/etc/scripts/mongologcleanup.txt
chmod 755 /etc/scripts/mongologcleanup.sh
#chmod 755 /etc/scripts/mongologcleanup.txt
#crontab /etc/scripts/mongologcleanup.txt
#crontab -l

#chmod 755 mongologrotation.sh

# Note: This will install the cron-file.txt to your crontab, which will also remove your old cron entries. 
# So, please be careful while uploading cron entries from a cron-file.txt.
# ref http://www.thegeekstuff.com/2009/06/15-practical-crontab-examples/

#mongodb backups
echo '#!/bin/bash

#mongodumps
#find /data_disk/mongo/backups/mongodumps/mongodump_* -mtime +10 -exec rm -r {} \;
find /data_disk/mongo/backups/mongodumps/mongodump_* -mtime +10 -delete;
#mongodump --out /data_disk/mongo/backups/mongodumps/mongodump_$(date +%Y%m%d-%H%H%M);
#zip -m -r mongobackup_$(date +%Y%m%d-%H%H%M).zip /data_disk/mongo/backups/mongodumps/mongodump_$(date +%Y%m%d-%H%H%M)
mongodump --gzip --out /data_disk/mongo/backups/mongodumps/mongodump_$(date +%Y%m%d-%H%M%S)' > /etc/scripts/mongodump.sh

#cat /etc/scripts/mongodump.sh

# now create the cron job to run the log cleanup bash script /etc/scripts/mongologcleanup.sh
# append after last line

echo '5 2 * * * root /etc/scripts/mongodump.sh' >> /etc/crontab
#echo '5 0 * * * /etc/scripts/mongologcleanup.sh'>/etc/scripts/mongologcleanup.txt
chmod 755 /etc/scripts/mongodump.sh
}

Install_step6()
{
# Disable THP is per mongo best practice
# Create a new custom tuned profile by copying the default tuned profile (virtual-guest in this case)
# Use the copied conf file and edit according to your need and have it echo back into your new custom profile config file

mkdir /usr/lib/tuned/no-thp
cp -r /usr/lib/tuned/virtual-guest/* /usr/lib/tuned/no-thp

# Change the /usr/lib/tuned/no-thp/tuned.conf file to include custom parameters [VM] [Disk] to echo back below
# delete all file content

ex -s +%d +%p +x /usr/lib/tuned/no-thp/tuned.conf

# insert custom config to echo back into /usr/lib/tuned/no-thp/tuned.conf

echo "#
# tuned configuration
#

[main]
include=throughput-performance

[sysctl]
# If a workload mostly uses anonymous memory and it hits this limit, the entire
# working set is buffered for I/O, and any more write buffering would require
# swapping, so it's time to throttle writes until I/O can catch up.  Workloads
# that mostly use file mappings may be able to use even higher values.
#
# The generator of dirty data starts writeback at this percentage (system defaul
# is 20%)
vm.dirty_ratio = 30

[vm]
transparent_hugepages=never

[disk]
readahead=>256

# Filesystem I/O is usually much more efficient than swapping, so try to keep
# swapping low.  It's usually safe to go even lower than this on systems with
# server-grade storage.
vm.swappiness = 30" > /usr/lib/tuned/no-thp/tuned.conf

# enable custom tuned profile

tuned-adm profile no-thp 

# check active profiles

tuned-adm active



# Disable THP-defrag using systemd

# Make a directory for your systemd scripts

mkdir /etc/systemd/system/scripts

# create your script file /etc/systemd/system/scripts/defrag.sh and echo your settings

echo '#!/bin/sh

#Script to disabble THP and defrag of it

if test -f /sys/kernel/mm/transparent_hugepage/khugepaged/defrag; then
  echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi' > /etc/systemd/system/scripts/defrag.sh

cat /etc/systemd/system/scripts/defrag.sh

# Change permission for your defrag.sh file

chmod 755 /etc/systemd/system/scripts/defrag.sh

# create your systemd service to disable THP-defrag on bootup
# /etc/systemd/system/defrag.service and echo your settings

echo '[Unit]
Description=Disable-THP-Defrag

[Service]
ExecStart=/etc/systemd/system/scripts/defrag.sh

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/defrag.service

cat /etc/systemd/system/defrag.service

# Change permission on /etc/systemd/system/defrag.service

chmod 755 /etc/systemd/system/defrag.service

# Enable the new systemd service /etc/systemd/system/defrag.service

systemctl enable defrag.service

# view service status (might require reboot first

systemctl status defrag.service

# Edit Ulimit as per mongo best practice, create new profile containing your new limits in /etc/security/limits.d/99-mongodb-nproc.conf

echo '#Ulimit for open files 
* soft nofile 64000
* hard nofile 64000

#Ulimit for processes/threads
* soft nproc 64000
* hard nproc 64000' > /etc/security/limits.d/99-mongodb-nproc.conf

cat /etc/security/limits.d/99-mongodb-nproc.conf

# Set keep alive to 120 as per mongodb production notes

sed -i:bak '$ a\net.ipv4.tcp_keepalive_time = 120' /etc/yum.conf /etc/sysctl.conf
}

Install_step7()
{
yum -y install https://cloud.mongodb.com/download/agent/automation/mongodb-mms-automation-agent-manager-latest.x86_64.rhel7.rpm
sed -i:bak 's/mmsGroupId=/mmsGroupId=65435776YOURNUMBER96445677676jhk/' /etc/mongodb-mms/automation-agent.config
sed -i:bak 's/mmsApiKey=/mmsApiKey=65435776YOURNUMBER96445677676jhk/' /etc/mongodb-mms/automation-agent.config
systemctl enable mongodb-mms-automation-agent.service
systemctl start mongodb-mms-automation-agent.service
}

Install_step8()
{
yum remove docker \
		   docker-common \
           docker-selinux \
           docker-engine
		   
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
	
yum makecache fast

#https://unix.stackexchange.com/questions/78512/bash-scripting-loop-until-return-value-is-0
#before continuing, loop until docker finish installing successfully or not
until yum -y install docker-ce #will install latest version
#yum install docker-ce-<VERSION> #install
do sleep 10s
done
systemctl enable docker
systemctl start docker

#run azcopy from docker image
echo '#!/bin/bash

docker run --rm -v /data_disk/mongo/backups/mongodumps:/tmp/azcopy farmer1992/azcopy:linux-latest azcopy \
--source /tmp/azcopy \
--destination https://prparchive.blob.core.windows.net/mongobackups --dest-key 65435776YOURNUMBER96445677676jhk== \ #Add your own dest key
--recursive' > /etc/scripts/azcopy.sh


# now create the cron job to run the log cleanup bash script /etc/scripts/mongologcleanup.sh
# append after last line

echo '5 5 * * *  root /etc/scripts/azcopy.sh' >> /etc/crontab
#echo '5 0 * * * /etc/scripts/mongologcleanup.sh'>/etc/scripts/mongologcleanup.txt
chmod 755 /etc/scripts/azcopy.sh
}

sudo sed -i:bak 's/Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

Install_step1
Install_step2a #dependent on Install_step2
Install_step3
Install_step4
Install_step5
Install_step6
Install_step7 #Install mongo mms automation agent. Add your own keys. Edit out if not needed.
Install_step8 #AzCopy in Docker to move mongodumps to Azure Blob. Add your own keys. Edit out if not needed.

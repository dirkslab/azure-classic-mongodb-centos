#!/bin/bash

# Pre-requisites
# Install linux vm with attached data disks
# Script based on 4x Data disks


Install_step1()
{
# Enable swap file on the linux machine through azure agent file waagent.conf and disable selinux using the ex search replace editor

ex -s +%s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g +%p +x /etc/waagent.conf
ex -s +%s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=5120/g +%p +x /etc/waagent.conf

ex -s +%s/SELINUX=enforcing/SELINUX=disabled/g +%p +x /etc/selinux/config
}

Install_step2()
{
# configure partition on each disk, config blow is based on 4 attached data disks

hdd="/dev/sdc /dev/sdd /dev/sde /dev/sdf"
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

Install_step3()
{
# install mdam

yum -y install mdadm

# Create the raid device using 4 data disks- DataRaid

mdadm --create /dev/md127 --level 0 --raid-devices 4  /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1

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
   replSetName: "rs2"' > /etc/mongod.conf

# Create Mongo directories

mkdir /data_disk/mongo
mkdir /data_disk/mongo/logs
mkdir /data_disk/mongo/data

# change ownership and group

chown -R mongod:mongod /data_disk
chown -R mongod:mongod /data_disk/mongo
chown -R mongod:mongod /data_disk/mongo/logs
chown -R mongod:mongod /data_disk/mongo/data

# setup log rotation by using linux cron job to run bash script
# first create your bash script.
 
echo '#!/bin/bash

# This script below will rename the mongod log file with the date appended and open a new log file;
# we will then search for renamed log files older than 5 days and zip
# maintenance- we will then find renamed files older than 31 days and delete

/bin/kill -SIGUSR1 `cat /data_disk/mongo/data/mongod.lock 2> /dev/null`
find /data_disk/mongo/logs/mongod.log.* -mtime +5 -execdir zip '{}'.zip '{}' -m -x *.zip \;
find /data_disk/mongo/logs/mongod.log.* -mtime +31 -exec rm {} \;' > /etc/scripts/mongologrotation.sh

cat /etc/scripts/mongologrotation.sh

# now create the cron job to run the log rotation bash script /etc/scripts/mongologrotation.sh
# append after last line

echo '5 0 * * * /etc/scripts/mongologrotation.sh'>/etc/scripts/mongologrotation.txt
crontab /etc/scripts/mongologrotation.txt
crontab -l

chmod 755 mongologrotation.sh  

# Note: This will install the cron-file.txt to your crontab, which will also remove your old cron entries. 
# So, please be careful while uploading cron entries from a cron-file.txt.
# ref http://www.thegeekstuff.com/2009/06/15-practical-crontab-examples/
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
yum -y install https://cloud.mongodb.com/download/agent/automation/mongodb-mms-automation-agent-manager-3.1.0.1831-1.x86_64.rhel7.rpm
sed -i:bak 's/mmsGroupId=/mmsGroupId=57e3e80c3b34b92da9e86270/' /etc/mongodb-mms/automation-agent.config
sed -i:bak 's/mmsApiKey=/mmsApiKey=8089dd927f145674473ed02fbb954ca7/' /etc/mongodb-mms/automation-agent.config
systemctl enable mongodb-mms-automation-agent.service
systemctl start mongodb-mms-automation-agent.service
}

sudo sed -i:bak 's/Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

Install_step1
Install_step2
Install_step3
Install_step4
Install_step5
Install_step6
Install_step7

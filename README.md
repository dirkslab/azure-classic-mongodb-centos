# azure-classic-mongodb-centos
Please note powershell script is semi interactive!

Situation where you need to use Classic deployment model. 
OS base is Centos with latest mongodb repository at the time.
Using simple powershell deployment to deploy server and shell extension to configure server for attached datadisks,
best practice use setup for mongodb and installation of mongodb with replica set config.

Extension script is based on 7 function steps. Final step I have commented out, but can be included to install automation agent for MMS.
Just edit the detail to reflect your key.

This script is mainly intended to add single mongodb servers to existing replica sets. You could create a new replica set, but will need to initialize the replica set once you have your machines up and running.


# some knowns

the extension shell script:
very rough and can be improved.
hard coded for  x4 data disk setup - hope to improve this
no logging, no quick way to tell if script is complete- I generally login via ssh and run sudo lsblk command. If the raid setup is completed, script generally completed. not ideal
server needs a reboot after this before mongo starts (prob due to disabling SELINUX) -to fix

# how to use

download ps1 script
edit ValidateSet for $SubscriptionName and $newstorageaccconfirm
run ps1 script from location and use tab to run and set parameter options
interact with script by filling in requested detail as it pops up in powershell and Gridview respectively.

example:
PS C:\temp> .\new-azurevmv-github.ps1 -SubscriptionName 'subscription-example4' -newcloudserviceconfirm yes -newcloudservicename atestmongocloud -vmName atestmongosvr -newstorageaccconfirm yes -vmSize Standard_D2_v2 -AzureLocation 'North Europe' -datadiskconfirmation yes -numDiskPrompt 4 -verbose

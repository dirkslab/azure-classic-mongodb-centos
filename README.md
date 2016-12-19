# azure-classic-mongodb-centos
Please note powershell script is semi interactive!

Situation where you need to use Classic deployment model. 
OS base is Centos with latest mongodb repository at the time.
Using simple powershell deployment to deploy server and shell extension to configure server for attached datadisks,
best practice use setup for mongodb and installation of mongodb with replica set config.

Extension script is based on 7 function steps. Final step I have commented out, but can be included to install automation agent for MMS.
Just edit the detail to reflect your key.

# some knowns

the extension script:
very rough and can be improved.
hard coded 4 data disk setup - hope to improve this 

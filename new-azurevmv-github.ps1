[CmdletBinding()]
Param(
#####Set1#####
    [Parameter(
        Position = 0,
        Mandatory = $True,
        HelpMessage = "Choose the subscription to use. Yes or No"
        )
      ]
    [ValidateSet(
        "subscription-example1",                            
        "subscription-example2",     
        "subscription-example3",                          
        "subscription-example4",
        "subscription-example5"
        )
      ]
    [string] $SubscriptionName,
#####Set2#####
    [Parameter(
        Position = 1,
        Mandatory,
        HelpMessage = "Will you be creating a new CloudService. Yes or No"
        )
      ]
    [ValidateSet(
        "yes",
        "no"
        )
      ]
    [string] $newcloudserviceconfirm,
#####Set3#####
    [Parameter(
        HelpMessage = "Please supply new Cloud Service Name"
        )
      ]
    [string] $newcloudservicename,
#####Set4#####
    [Parameter(
        HelpMessage = "What is your new Azure vm name'"
        )
      ]
    [string] $vmName,
#####Set5#####
    [Parameter(Mandatory,
        HelpMessage = "Will you be creating a new AzureStorageAccount. Yes or No"
        )
      ]
    [ValidateSet(
        "yes",
        "no"
        )
      ]
    [string] $newstorageaccconfirm,
#####Set6#####
    [Parameter(Mandatory,HelpMessage = "Choose vmsize")]
    [ValidateSet(
        "Standard_A0",
        "Standard_A1",
        "Standard_A2",
        "Standard_A3",
        "Standard_A4",
        "Standard_D2_v2",
        "Standard_D11_v2"
       )
     ]
    [string] $vmSize,
#####Set7#####
    [Parameter(Mandatory,
    HelpMessage = "Azure Location"
        )
      ]
    [ValidateSet(
        "North Europe"
        )
      ]
    [string] $AzureLocation,
#####Set8#####
    [Parameter(
        Mandatory,
        HelpMessage = "Will you be adding data disks to your new vm deployment. Yes or No"
        )
      ]
    [ValidateSet(
        "yes",
        "no"
        )
      ]
    [string] $datadiskconfirmation,
#####Set9#####
    [Parameter(HelpMessage = "How many data disks would you like to add")]
    [int] $numDiskPrompt
)



#AdminName and Password
#Query Multiple Values at once with Prompt
#http://activedirectoryfaq.com/2014/12/user-interactive-powershell-scripts/


$title = "Login"
$message = "Please enter your SSH login username!"
$name = New-Object System.Management.Automation.Host.FieldDescription "Name"
$name.Label = "&Login Name"
$name.DefaultValue = "ppadmin"
$pwd = New-Object System.Management.Automation.Host.FieldDescription "Password"
$pwd.Label = "&Password"
#$pwd.SetparameterType( [System.Security.SecureString] )
$pwd.HelpMessage = "Please type your Password."
$fields = [System.Management.Automation.Host.FieldDescription[]]($name, $pwd)
$login=$Host.UI.Prompt($title, $message, $fields)

if (-not $login.Password)
        {
            # User cancelled.  Here we'll just return nothing, but you may want to
            # throw an exception instead, depending on how the calling code should
            # behave.

            Write-Warning "Password cannot be blank" -ForegroundColor Red -WarningAction Stop
           
        }


$AdminName = $login.Name

#password -Note: to investigate using  -assecurestring option, might need to be in clear text

$secure_password = $login.Password

#vnet and subnet to use

$x = (Get-AzureVNetSite) | select Name, AddressSpacePrefixes, subnets | Out-GridView -PassThru
$VNetName = $x.Name
Write-Host $VNetName -ForegroundColor Green

$x = Get-AzureVNetSite -VNetName $VNetName
$x = $x.subnets | Out-GridView -Title 'Choose a subnet' -PassThru
$Subnet = $x.name


#filter through images and select OS Disk
$imgName = (Get-AzureVMImage) | select ImageName, OS, Label, ImageFamily | Out-GridView -PassThru
$imgName = $imgName.ImageName

#Select the subscription you want to work in

#-#$x = Get-AzureSubscription | select SubscriptionName | Out-GridView -Title 'Choose Subscription' -PassThru 
#-#$SubscriptionName = $x.SubscriptionName
Select-AzureSubscription -SubscriptionName $SubscriptionName

#Azure Location 

#$AzureLocation = (Get-AzureLocation).Name | Out-GridView -Title 'Choose your location' -PassThru



###CloudService Action-Begin
#to use new or existing CloudService
#based on user input, action a function and save as variable
 
#-#$cloudconfirmation = Read-Host "Would you like to create a new CloudService. Yes or No"

if (($newcloudserviceconfirm -ne 'yes') -and ($newcloudserviceconfirm -ne 'no'))
    { 
        Write-Warning "Improper cloudservice input, cannot continue" -ErrorAction Stop
    }   
elseif ($newcloudserviceconfirm -eq 'yes') 
    {
#-#        $cloudservicename=Read-Host "Please supply new Cloud Service Name"
        Write-Host "Creating new service account" -ForegroundColor Yellow
        New-AzureService -ServiceName $newcloudservicename -Location $AzureLocation
        $xcloud = $newcloudservicename
        Write-Host "Finished creating new service account $xcloud" -ForegroundColor Green       
    }
else
    {
        $xcloud = (Get-AzureService).ServiceName| Out-GridView -Title 'Choose Cloud Service' -PassThru
    }
if (-not $xcloud)
    {
        Write-Warning "Cannot be empty" -ErrorAction Stop
    }

$servicename = $xcloud
###CloudService Action-End

#New vm name

#-#$vmName = Read-Host -Prompt 'What is your new Azure vm name' 



#machine size

#$vmSize = (Get-AzureLocation).VirtualMachineRoleSizes | Out-GridView -Title 'Choose VM Size' -PassThru

# Using Read-Host input to decide if you will be creating new storage accout or use existing one
# to console
# https://technet.microsoft.com/en-us/library/hh847789.aspx (-and -or explanation)

#-#$storageconfirmation = Read-Host "Will you be using existing AzureStorageAccount y/n"

if (($newstorageaccconfirm -ne 'yes') -and ($newstorageaccconfirm -ne 'no'))
    { 
        Write-Warning "Improper choise, cannot continue" -ErrorAction Stop
    }   
elseif ($newstorageaccconfirm -eq 'yes') 
    {
        $vmnamex = $vmName.ToLower()
        $pattern = '[^a-zA-Z1-9]'
        $vmnamexx = $vmnamex -replace $pattern, '' 
        $StorageAccountName = "$vmnamexx`storage"
        #$StorageAccountName = Read-Host "Type new AzureStorageAccount -no special characters -current format example: 'prpmongostorage015'"
        Write-Host "Creating new storage account $StorageAccountName" -ForegroundColor Yellow
        New-AzureStorageAccount -Location $AzureLocation -StorageAccountName $StorageAccountName
        Write-Host "finished creating new storage account $StorageAccountName" -ForegroundColor Green
    }
else
    {
        #using existing Storage account and medialocation
        #slect the storage account you want to use
        $x = (Get-AzureStorageAccount).StorageAccountName | Out-GridView -Title 'Choose Storage Account' -PassThru
        $StorageAccountName = $x
    }
if (-not $StorageAccountName)
    {
        Write-Warning "AzureStorageAccount cannot be empty" -ErrorAction Stop
    }

#set the storage account to be used

Set-AzureSubscription -SubscriptionName $SubscriptionName -CurrentStorageAccountName $StorageAccountName

#get the medialocation for the storage account you want to use

$x = Get-AzureStorageAccount -StorageAccountName $StorageAccountName
$medialocation = ($x).Endpoints | Where-Object {$_ -Like '*blob*'}
$medialocation | Write-Host -ForegroundColor Green

###vmconfig and creation of new vm -Begin

$NewVMConfig = New-AzureVMConfig -ImageName $imgName -InstanceSize $vmSize -Name $vmName -DiskLabel $vmName -HostCaching ReadWrite -Label $vmName -MediaLocation $medialocation/vhds/$vmName.vhd
Write-Host "Creating new vm $vmName" -ForegroundColor Yellow
$NewVMConfig | Add-AzureProvisioningConfig -Linux -LinuxUser $AdminName -Password $secure_password | Set-AzureSubnet -SubnetNames $Subnet | New-Azurevm -ServiceName $serviceName -VNetName $VNetName 
Write-Host "Finished creating new vm $vmName" -ForegroundColor Yellow

###vmconfig and creation of new vm -End


###Adding data disks -Begin
#-#$datadiskconfirmation = Read-Host "Will you be adding data disks to your new vm deployment y/n"
#-#$numDiskPrompt = Read-Host "how many data disks would you like"

if (($datadiskconfirmation -ne 'yes') -and ($datadiskconfirmation -ne 'no'))
    { 
        Write-Warning "Improper choise, cannot continue" -ErrorAction Stop
    }   
elseif ($datadiskconfirmation -eq 'yes') 
    {
        #Extra Data Disk info
        #DiskSize
        $ds = 1000

        #-#$numDiskPrompt=Read-Host "How many data disks would you like"
        #number of disks to add as well as Lun location
        #we subtract 1 as disk and lun count start at 0 
        $numDiskPrompt = $numDiskPrompt - 1
        #create an array with required disk numbers
        $diskNumber = 0..$numDiskPrompt

        #Set data disk HostCaching to None, ReadOnly or ReadWrite
        $HostCache = "ReadWrite"
        
        $SelectedVM = Get-AzureVM -ServiceName $servicename -Name $vmName

        #$Datadisk = "$vmname-Data-$date"
        $Datadisk = "$vmName-data"

        # get Disk Location from VM
        $MediaLocation = (Get-AzureOsDisk -VM $SelectedVM).MediaLink
        $MediaLocation = $MediaLocation.Host
        write-host $MediaLocation -ForegroundColor Green
        Write-Host "Creating and attaching data disks" -ForegroundColor Yellow

        $i = $diskNumber
        $i | foreach { $SelectedVM | Add-AzureDataDisk -CreateNew -MediaLocation "https://$medialocation/vhds/$vmName-Data$_.vhd" -DiskSizeInGB $ds -DiskLabel "$DataDisk" -LUN $_ –HostCaching $HostCache | Update-AzureVM }        
        Write-Host "Finished creating and attaching data disks" -ForegroundColor Green
    }

###Adding data disks -End

#https://azure.microsoft.com/en-us/blog/automate-linux-vm-customization-tasks-using-customscript-extension/
#Sample PowerShell Script to run a Linux Shell script stored in Azure blob
#Enter the VM name, Service name, Azure storage account name and key
#$SelectedVM = Get-AzureVM -ServiceName "MyService" -Name "MyVM"
#$PrivateConfiguration = '{"storageAccountName": "MyAccount","storageAccountKey":"Mykey"}' 
#Specify the Location of the script from Azure blob, and command to execute
$PublicConfiguration = '{"fileUris":["https://raw.githubusercontent.com/dirkslab/azure-classic-mongodb-centos/master/mongodb-repl-setup1.sh"], "commandToExecute": "sh mongodb-repl-setup1.sh" }' 
	
#Deploy the extension to the VM, always use the latest version by specify version “1.*”
$ExtensionName = 'CustomScriptForLinux'  
$Publisher = 'Microsoft.OSTCExtensions'  
$Version = '1.*' 
Set-AzureVMExtension -ExtensionName $ExtensionName -VM $SelectedVM -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration  | Update-AzureVM

Write-Host $vmName -ForegroundColor Magenta
Write-Host "Remote Connection Info" -ForegroundColor Yellow
Write-Host $SelectedVM.DNSName -ForegroundColor Green
$x = $SelectedVM | get-AzureEndpoint 
$AzureEndpoint = $x.Port  
Write-Host "Port $AzureEndpoint" -ForegroundColor Green

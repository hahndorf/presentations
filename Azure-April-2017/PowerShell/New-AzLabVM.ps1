[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    [int]$MachineId = 1,
    [string]$ResourceGroupName = "hcLAB",
    [string]$subscriptionId = "82ced291-8a55-46ca-86d4-064c97268779",
    [string]$commonPrefix = "hclab",
    [switch]$CustomAdminPassword,
    [switch]$ssd
)

Begin
{

    $paramterFile = [System.IO.Path]::GetTempFileName()

    $storageAccountType = "Standard_LRS"
    if ($ssd)
    {
        # tell Azure to use an SSD for the OS disk, this is called Premium
        # but it is more expensive.
        $storageAccountType = "Premium_LRS"  
    }

    Function AskForPassword()
    {
        $ph = Read-Host "Type the admin password to use" -AsSecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ph))  
    }

    Function CreateParametersFile([string]$id)
    {

     $content = @"
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "southeastasia"
        },
        "virtualMachineName": {
            "value": "$commonPrefix$id"
        },
        "virtualMachineSize": {
            "value": "Standard_DS1_v2"
        },
        "adminUsername": {
            "value": "adm_peter"
        },
        "virtualNetworkName": {
            "value": "$commonPrefix-vnet"
        },
        "networkInterfaceName": {
            "value": "$($commonPrefix)nic$id"
        },
        "networkSecurityGroupName": {
            "value": "$commonPrefix$id-nsg"
        },
        "adminPassword": {
            "value": "$adminPassword"
        },
        "storageAccountName": {
            "value": "$($commonPrefix)diskslab$id"
        },
        "storageAccountType": {
            "value": "Premium_LRS"
        },
        "diagnosticsStorageAccountName": {
            "value": "$($commonPrefix)diaglab$id"
        },
        "diagnosticsStorageAccountType": {
            "value": "$storageAccountType"
        },
        "diagnosticsStorageAccountId": {
            "value": "Microsoft.Storage/storageAccounts/$($commonPrefix)diaglab$id"
        },
        "addressPrefix": {
            "value": "10.0.0.0/24"
        },
        "subnetName": {
            "value": "default"
        },
        "subnetPrefix": {
            "value": "10.0.0.0/24"
        },
        "publicIpAddressName": {
            "value": "$($commonPrefix)$id-ip"
        },
        "publicIpAddressType": {
            "value": "Dynamic"
        }
    }
}
"@

     $content | Out-File -FilePath $paramterFile -Verbose
    }

    Function New-AzureLabVM()
    {
        if ($pscmdlet.ShouldProcess($ResourceGroupName,"Create-VM $commonPrefix$MachineId")){ 
            .\New-AzVM.ps1 -subscriptionId $subscriptionId -resourceGroupName $ResourceGroupName -deploymentName "Deploy$MachineId" -templateFilePath .\template.json -parametersFilePath $paramterFile
        }
    }
}

Process
{

    Try {
      Get-AzureRmContext
    } Catch {
      if ($_ -like "*Login-AzureRmAccount to login*") {
        Write-Warning "You are not logged into Azure, run Add-AzureRmAccount and then start this script again"
        Exit       
      }
    }

    if ($CustomAdminPassword)
    {
        $adminPassword = AskForPassword
    }
    else
    {
        # we get the password from our credential store
        $adminPassword = Get-SecretText.ps1 -name "hc:azureLabPassword"

        if ($adminPassword -eq $null)
        {  
            $adminPassword = AskForPassword
        }    
    }

    CreateParametersFile -id $MachineId

# PS C:\> Install-Module AzureRM
# PS C:\> Install-AzureRM

    New-AzureLabVM

}

End
{
    Remove-item -Path $paramterFile
}

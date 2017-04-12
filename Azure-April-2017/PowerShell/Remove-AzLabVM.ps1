[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    [int]$MachineId,
    [string]$ResourceGroupName = "hcLAB",
    [string]$subscriptionId = "82ced291-8a55-46ca-86d4-064c97268779",
    [string]$commonPrefix = "hclab"
)

Begin
{
    [string]$script:IPToRemove = ""

    function Get-VMDisks($vm)
    {
        #Function to get all disks attached to a VM
        $disks = @()
        $disks += ,$vm.StorageProfile.OsDisk.Vhd.Uri
        foreach ($disk in $vm.StorageProfile.DataDisks)
        {
        $disks += ,$disk.Vhd.Uri
        }
        return $disks
    }
 
    function Delete-Disk($uri)
    {
        #Function to get delete disk and delete the container if it is empty
        $uriSplit = $uri.Split("/").Split(".")
        $saName = $uriSplit[2]
        $container = $uriSplit[$uriSplit.Length-3]
        $blob = $uriSplit[$uriSplit.Length-2] + ".vhd"
        $sa = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq $saName}
        $saKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName).Value[0]
        $saContext = New-AzureStorageContext -StorageAccountName $sa.StorageAccountName -StorageAccountKey $saKey
        Remove-AzureStorageBlob -Blob $blob -Container $container -Context $saContext
 
        $remainingBlobs = Get-AzureStorageContainer -Name $container -Context $saContext | Get-AzureStorageBlob
 
        if ($remainingBlobs -eq $null)
        {
            Remove-AzureStorageContainer -Name $container -Context $saContext -Force
        }
    }
 
    function Get-VMNIC($vm)
    {
        $nic = $vm.NetworkInterfaceIDs.split("/") | Select-Object -Last 1

        $nic

        $ipPath = (Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nic).IpConfigurations[0].PublicIpAddress.Id

# $foo = "/subscriptions/82ced291-8a55-46ca-86d4-064c97268779/resourceGroups/hcLAB/providers/Microsoft.Network/publicIPAddresses/hclab1-ip"

        $ismatch = $ipPath -match "[^/][-a-z0-9]+$"

        $script:IPToRemove = $Matches.Values[0]

        return $nic
    }

    function RemoveIPAddress([string]$name)
    {
     #   Remove-AzureRmPublicIpAddress -Name "$commonPrefix$MachineId-ip" -ResourceGroupName $ResourceGroupName -Force
        Remove-AzureRmPublicIpAddress -Name "$name" -ResourceGroupName $ResourceGroupName -Force       
    }

    function RemoveStorageAccounts()
    {
        Remove-AzureRmStorageAccount -ResourceGroupName "$ResourceGroupName" -AccountName "$($commonPrefix)diskslab$MachineId" -Force
        Remove-AzureRmStorageAccount -ResourceGroupName "$ResourceGroupName" -AccountName "$($commonPrefix)diaglab$MachineId" -Force
    }

    Function RemoveNetworkSecurityGroup()
    {
        Remove-AzureRmNetworkSecurityGroup -Name "$commonPrefix$MachineId-nsg" -ResourceGroupName "$ResourceGroupName" -Force
    }

    Function RemoveAzVM($vm)
    {
        $disksToDelete = @()
        $nicToDelete = @()
 
        $disksToDelete = Get-VMDisks($vm)
        $nicToDelete = Get-VMNIC($vm)
        Write-Host "Deleting VM:" $vm.Name -ForegroundColor Yellow
        Remove-AzureRmVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
        Write-Host "Deleting NIC:" $nicToDelete -ForegroundColor Yellow
        Remove-AzureRmNetworkInterface -Name $nicToDelete -ResourceGroupName $vm.ResourceGroupName -Force

        foreach ($disk in $disksToDelete)
        {
            Write-Host "Deleting Disk:" $disk -ForegroundColor Yellow
            Delete-Disk($disk)
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

    Select-AzureRmSubscription -SubscriptionID $subscriptionId;
 
    $vmToRemove = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name "$commonPrefix$MachineId"

    # stop the VM
    $vmToRemove | Stop-AzureRmVM -Force

    RemoveAzVM -vm $vmToRemove
    RemoveStorageAccounts
    RemoveIPAddress -name $script:IPToRemove
    RemoveNetworkSecurityGroup
}

End
{

}

$rgname = "RG_VS16153"
$vmname = "sh-superhub"
$vmsize = "Standard_B2s"
$vmnic = "sh-superhub-nic1"
$vmstorage = "azurehkstorage01"
$vhduri="https://azurehkstorage01.blob.core.windows.net/vhds/hk-superhub20190414211451.vhd"
$vhddiskname="sh-superhub-0-osdisk"


#$vmconfig = New-AzureRmVMConfig -VMName $vmname  -VMSize $vmsize
#$vm = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id (Get-AzureRmNetworkInterface -Name $vmnic -ResourceGroupName $rgname).Id
#$vm = Set-AzureRmVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $rgname -StorageAccountName $vmstorage
#$vm = Set-AzureRmVMOSDisk -VM $vm -VhdUri $vhduri  -CreateOption Attach -Name $vhddiskname -Windows
#New-AzureRmVM -ResourceGroupName $rgname -Location (Get-AzureRmResourceGroup $rgname).Location -VM $vm -Verbose -Debug

$vmconfig=New-AzVMConfig -VMName $vmname -VMSize $vmsize
$vm=Add-AzVMNetworkInterface -VM $vmconfig -Id (Get-AzNetworkInterface -Name $vmnic -ResourceGroupName $rgname).Id
$vm=Set-AzVMBootDiagnostic -VM $vm -Enable -ResourceGroupName $rgname -StorageAccountName $vmstorage
$vm = Set-AzVMOSDisk -VM $vm -VhdUri $vhduri -CreateOption Attach -Name $vhddiskname -Windows
New-AzVM -ResourceGroupName $rgname -Location "East Asia" -VM $vm -Verbose  # as my RG is in Different Region
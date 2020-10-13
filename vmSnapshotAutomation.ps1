<#
    .NOTES
        ==============================================================================================
        Copyright (c) Jessy DESLOGES. All rights reserved.
        File:		vmSnapshotAutomation
        Purpose:	VM Snapshot Automation Runbook
        Version: 	1.1
        ==============================================================================================

        DISCLAIMER
        ==============================================================================================
        This script is not supported under any Microsoft standard support program or service.

        This script is provided AS IS without warranty of any kind.
        Microsoft further disclaims all implied warranties including, without limitation, 
        any implied warranties of merchantability or of fitness for a particular purpose.

        The entire risk arising out of the use or performance of the script
        and documentation remains with you. In no event shall Microsoft, its authors,
        or anyone else involved in the creation, production, or delivery of the
        script be liable for any damages whatsoever (including, without limitation,
        damages for loss of business profits, business interruption, loss of business
        information, or other pecuniary loss) arising out of the use of or inability
        to use the sample scripts or documentation, even if Microsoft has been
        advised of the possibility of such damages.

    .SYNOPSIS
        VM Snapshot Automation Runbook

    .DESCRIPTION
        Use this runbook to automate VM snapshot for legacy purpose (when Azure Backup can't be used like for W2008 32 bit VMs)

    .PARAMETER RetentionDays
        Specify number of rentention days. VM snapshots will be automatically and definitely removed if RetentionDays is reached. 

    .EXAMPLE
        C:\PS> .\vmSnapshotAutomation.ps1 -RetentionDays 7
#>
Param
(
    [Parameter(Mandatory = $true)]
    [Int] $RetentionDays
)

Import-Module -Name AzureRM.Compute
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#ForEach subscriptions
Write-Warning "## PHASE 1 : CREATE VM SNAPSHOT"
$Subscriptions = Get-AzureRMSubscription
foreach ($Subscription in $Subscriptions)
{
    set-azurermcontext -subscriptionid $Subscription.subscriptionid 

    #ForEach VMs
    $Vms = get-AzureRMVM | Select Name,Tags,Id,Location,ResourceGroupName
    foreach($Vm in $Vms)
    {
        #FoeEach VM tag "Snapshot = True"
        foreach($tag in $Vm.Tags)   
        {
            if($tag.Snapshot -eq 'True')
            {
                #ForEach disks
                $disks = get-azurermdisk | select managedby,location,Id,Name,ResourceGroupName | where {$_.managedby -like "*"+ $VM.name}
                Write-Output "Found $($disks.count) disks for $($vm.name) !"
                foreach($disk in $disks)
                {
                    #Prepare snapshot : config
                    $snapshotconfig = New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $disk.Location -AccountType Standard_LRS
                    $SnapshotName = $disk.Name+"_"+(Get-Date -Format "yyyy-MM-dd-hh-mm-ss")

                    #Prepare snapshot : target (where "SnapshotTarget = True")
                    $RGs = Get-AzureRmResourceGroup
                    foreach($rg in $Rgs)
                    {
                        $RGName = $rg.ResourceGroupName
                        foreach($tag in $rg.tags)
                        {
                            if ($tag.SnapshotTarget -eq 'True')
                            {
                                Write-Warning "$RGName as SnapshotTarget detected ! ..."
                                Write-Warning "Creating $SnapshotName VM snapshot in $RGName ..."
                                New-AzureRmSnapshot -Snapshot $snapshotconfig -SnapshotName $SnapshotName -ResourceGroupName $rg.ResourceGroupName
                            }
                        }
                    }
                }
            }
        }
    }

    # Clean snapshot
    Write-Warning "## PHASE 2 : CLEAN UP VM SNAPSHOTS"
    $RGs = Get-AzureRmResourceGroup
    foreach($rg in $RGs)
    {
        foreach($tag in $rg.tags)
        {
            if ($tag.SnapshotTarget -eq 'True')
            {
                $RGName = $rg.ResourceGroupName
                Write-Warning "$RGName is Snapshot Target !"

                $Snapshots = Get-AzureRmSnapshot -ResourceGroupName $rg.ResourceGroupName
                ForEach ($Snapshot in $Snapshots)
                {
                    If ((($Snapshot.TimeCreated).ToString('yyyyMMddhhmmss')) -lt ([datetime]::Today.AddDays(-$RetentionDays).tostring('yyyyMMddhhmmss')))
                    {
                        $SnapshotName = $Snapshot.Name
                        Write-Warning "Removing $SnapshotName VM snapshot from $RGName ..."
                        Remove-AzureRmSnapshot -ResourceGroupName $RGName -SnapshotName $SnapshotName -Force
                    }
                }

            }
        }
    }
}
<#
.SYNOPSIS
  Connects to Azure and starts all VMs (ASM and ARM) in the specified subscription.

.DESCRIPTION
  This runbook connects to Azure and starts all VMs (ASM and ARM) in the specified Azure subscription.  
  You can attach a schedule to this runbook to run it at a specific time.
  This runbook uses cmdlets from the version 1.0.3 of Azure modules.

.PARAMETER AzureCredentialAssetName
   Optional with default of "AzureCredential".
   The name of an Automation credential asset that contains the Azure AD user credential with authorization for this subscription. 
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.

.PARAMETER AzureSubscriptionIdAssetName  
   Optional with default of "AzureSubscriptionId".  
   The name of an Automation variable asset that contains the GUID for this Azure subscription.  
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.  

.NOTES
   REQUIRED: You need to update all your Azure modules to version 1.0.3 before running this runbook.
   LASTEDIT: March 5, 2016
#>

param (
    [Parameter(Mandatory=$false)] 
    [String]$AzureCredentialAssetName = 'AzureCredential',
	
    [Parameter(Mandatory=$false)] 
    [String]$AzureSubscriptionIDAssetName = 'AzureSubscriptionId'
)

# Setting error and warning action preferences
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

# Connecting to Azure
$Cred = Get-AutomationPSCredential -Name $AzureCredentialAssetName -ErrorAction Stop
$null = Add-AzureAccount -Credential $Cred -ErrorAction Stop -ErrorVariable err
$null = Add-AzureRmAccount -Credential $Cred -ErrorAction Stop -ErrorVariable err

# Selecting the subscription to work against
$SubID = Get-AutomationVariable -Name $AzureSubscriptionIDAssetName
Select-AzureRmSubscription -SubscriptionId $SubID

# Getting all resource groups
$ResourceGroups = (Get-AzureRmResourceGroup -ErrorAction Stop).ResourceGroupName

if ($ResourceGroups)
{
    foreach ($ResourceGroup in $ResourceGroups)
    {
        "`n$ResourceGroup"
        
        # Getting all virtual machines
        $RmVMs = (Get-AzureRmVM -ResourceGroupName $ResourceGroup -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Name
        
        # Managing virtual machines deployed with the Resource Manager deployment model
        if ($RmVMs)
        {
            foreach ($RmVM in $RmVMs)
            {
                $RmPState = (Get-AzureRmVM -ResourceGroupName $ResourceGroup -Name $RmVM -Status -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Statuses.Code[1]

                if ($RmPState -eq 'PowerState/running')
                {
                    "`t$RmVM is already started."
                }
                else
                {
                    "`t$RmVM is starting ..."
                    $RmSState = (Start-AzureRmVM -ResourceGroupName $ResourceGroup -Name $RmVM -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).IsSuccessStatusCode

                    if ($RmSState -eq 'True')
                    {
                        "`t$RmVM has been started."
                    }
                    else
                    {
                        "`t$RmVM failed to start."
                    }
                }
            }
        }
        else
        {  
            "`tNo VMs deployed with the Resource Manager deployment model."      
        }
       
        # Managing virtual machines deployed with the classic deployment model
		$VMs = (Get-AzureVM -ServiceName $ResourceGroup -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Name

        if ($VMs)
        {
            foreach ($VM in $VMs)
            {
                $PState = (Get-AzureVM -ServiceName $ResourceGroup -Name $VM -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).PowerState

                if ($PState -eq 'started')
                {
                    "`t$VM is already started."
                }
                else
                {
                    "`t$VM is starting ..."
                    $SState = (Start-AzureVM -ServiceName $ResourceGroup -Name $VM -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).OperationStatus

                    if ($SState -eq 'Succeeded')
                    {
                        "`t$VM has been started."
                    }
                    else
                    {
                        "`t$VM failed to start."
                    }
                }
            }
        }
        else
        {  
            "`tNo VMs deployed with the classic deployment model."
        }
    }
}
else
{
    "`tNo resource group found."
}
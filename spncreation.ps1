param
(
    [Parameter(Mandatory=$true, HelpMessage="Enter Azure Subscription name. You need to be Subscription Admin to execute the script")]
    [string] $subscriptionName,

    [Parameter(Mandatory=$true, HelpMessage="Provide a password for SPN application that you would create; this becomes the service principal's security key")]
    [securestring] $password,

    [Parameter(Mandatory=$false, HelpMessage="Provide a SPN role assignment")]
    [string] $spnRole = "owner",
    
    [Parameter(Mandatory=$false, HelpMessage="Provide Azure environment name for your subscription")]
    [string] $environmentName = "<replace with environment name>"
)

function Get-AzureCmdletsVersion
{
    $module = Get-Module Az -ListAvailable
    if($module)
    {
        return ($module).Version
    }
    return (Get-Module Az -ListAvailable).Version
}

function Get-Password
{
    $currentAzurePSVersion = Get-AzureCmdletsVersion
    $minAzurePSVersion = New-Object System.Version(5, 6, 0)

    if($currentAzurePSVersion -and $currentAzurePSVersion -ge $minAzurePSVersion)
    {
        return $password
    }
    else
    {
        $basicPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($basicPassword)

        return $plainPassword
    }
}

# Initialize
$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"
$userName = ($env:USERNAME).Replace(' ', '')
$newguid = [guid]::NewGuid()
$displayName = [String]::Format("AzDevOps.{0}.{1}", $userName, $newguid)
$homePage = "http://" + $displayName
$identifierUri = $homePage


# Initialize subscription
$isAzureModulePresent = Get-Module -Name Az -ListAvailable
if ([String]::IsNullOrEmpty($isAzureModulePresent) -eq $true)
{
    Write-Output "Script requires Azure PowerShell modules to be present. Obtain Azure PowerShell from https://github.com/Azure/azure-powershell/releases." -Verbose
    return
}

Import-Module -Name Az.Accounts
Write-Output "Provide your credentials to access your Azure subscription $subscriptionName" -Verbose
Connect-AzAccount -SubscriptionName $subscriptionName -EnvironmentName $environmentName
$azureSubscription = Get-AzSubscription -SubscriptionName $subscriptionName
$connectionName = $azureSubscription.Name
$tenantId = $azureSubscription.TenantId
$id = $azureSubscription.SubscriptionId


# Create a new AD Application
Write-Output "Creating a new Application in AAD (App URI - $identifierUri)" -Verbose
$password = Get-Password
$azureAdApplication = New-AzADApplication -DisplayName $displayName -HomePage $homePage -IdentifierUris $identifierUri -Password $password -Verbose
$appId = $azureAdApplication.AppId
Write-Output "Azure AAD Application creation completed successfully (Application Id: $appId)" -Verbose


# Create new SPN
Write-Output "Creating a new SPN" -Verbose
$spn = New-AzADServicePrincipal -ApplicationId $appId
$spnName = $spn.DisplayName
Write-Output "SPN creation completed successfully (SPN Name: $spnName)" -Verbose


# Assign role to SPN
Write-Output "Waiting for SPN creation to reflect in Directory before Role assignment"
Start-Sleep 20
Write-Output "Assigning role ($spnRole) to SPN App ($appId)" -Verbose
New-AzRoleAssignment -RoleDefinitionName $spnRole -ServicePrincipalName $spn.AppId
Write-Output "SPN role assignment completed successfully" -Verbose


# Print the values
Write-Output "`nCopy and Paste below values for Service Connection" -Verbose
Write-Output "***************************************************************************"
Write-Output "Connection Name: $connectionName(SPN)"
Write-Output "Environment: $environmentName"
Write-Output "Subscription Id: $id"
Write-Output "Subscription Name: $connectionName"
Write-Output "Service Principal Id: $appId"
Write-Output "Service Principal key: <Password that you typed in>"
Write-Output "Tenant Id: $tenantId"
Write-Output "***************************************************************************"

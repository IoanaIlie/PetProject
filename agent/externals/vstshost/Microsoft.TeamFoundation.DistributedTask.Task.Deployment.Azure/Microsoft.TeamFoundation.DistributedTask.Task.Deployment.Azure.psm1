﻿<#
    Microsoft.TeamFoundation.DistributedTask.Task.Deployment.Azure.psm1
#>

function Get-AzureCmdletsVersion
{
    $module = Get-Module AzureRM
    if($module)
    {
        return ($module).Version
    }
    return (Get-Module Azure).Version
}

function Get-AzureVersionComparison
{
    param
    (
        [System.Version] [Parameter(Mandatory = $true)]
        $AzureVersion,

        [System.Version] [Parameter(Mandatory = $true)]
        $CompareVersion
    )

    $result = $AzureVersion.CompareTo($CompareVersion)

    if ($result -lt 0)
    {
        #AzureVersion is before CompareVersion
        return $false 
    }
    else
    {
        return $true
    }
}

function Set-CurrentAzureSubscription
{
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $azureSubscriptionId,
        
        [String] [Parameter(Mandatory = $false)]  #publishing websites doesn't require a StorageAccount
        $storageAccount
    )

    if (Get-SelectNotRequiringDefault)
    {                
        Write-Host "Select-AzureSubscription -SubscriptionId $azureSubscriptionId"
        # Assign return value to $newSubscription so it isn't implicitly returned by the function
        $newSubscription = Select-AzureSubscription -SubscriptionId $azureSubscriptionId        
    }
    else
    {
        Write-Host "Select-AzureSubscription -SubscriptionId $azureSubscriptionId -Default"
        # Assign return value to $newSubscription so it isn't implicitly returned by the function
        $newSubscription = Select-AzureSubscription -SubscriptionId $azureSubscriptionId -Default
    }
    
    if ($storageAccount)
    {
        Write-Host "Set-AzureSubscription -SubscriptionId $azureSubscriptionId -CurrentStorageAccountName $storageAccount"
        Set-AzureSubscription -SubscriptionId $azureSubscriptionId -CurrentStorageAccountName $storageAccount
    }
}

function Set-CurrentAzureRMSubscription
{
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $azureSubscriptionId,
        
        [String]
        $tenantId
    )

    if([String]::IsNullOrWhiteSpace($tenantId))
    {
        Write-Host "Select-AzureRMSubscription -SubscriptionId $azureSubscriptionId"
        # Assign return value to $newSubscription so it isn't implicitly returned by the function
        $newSubscription = Select-AzureRMSubscription -SubscriptionId $azureSubscriptionId
    }
    else
    {
        Write-Host "Select-AzureRMSubscription -SubscriptionId $azureSubscriptionId -tenantId $tenantId"
        # Assign return value to $newSubscription so it isn't implicitly returned by the function
        $newSubscription = Select-AzureRMSubscription -SubscriptionId $azureSubscriptionId -tenantId $tenantId
    }
}

function Get-SelectNotRequiringDefault
{
    $azureVersion = Get-AzureCmdletsVersion

    #0.8.15 make the Default parameter for Select-AzureSubscription optional
    $versionRequiring = New-Object -TypeName System.Version -ArgumentList "0.8.15"

    $result = Get-AzureVersionComparison -AzureVersion $azureVersion -CompareVersion $versionRequiring

    return $result
}

function Get-RequiresEnvironmentParameter
{
    $azureVersion = Get-AzureCmdletsVersion

    #0.8.8 requires the Environment parameter for Set-AzureSubscription
    $versionRequiring = New-Object -TypeName System.Version -ArgumentList "0.8.8"

    $result = Get-AzureVersionComparison -AzureVersion $azureVersion -CompareVersion $versionRequiring

    return $result
}

function Set-UserAgent
{
    if ($env:AZURE_HTTP_USER_AGENT)
    {
        try
        {
            [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent($UserAgent)
        }
        catch
        {
        Write-Verbose "Set-UserAgent failed with exception message: $_.Exception.Message"
        }
    }
}

function Initialize-AzureSubscription 
{
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $ConnectedServiceName,

        [String] [Parameter(Mandatory = $false)]  #publishing websites doesn't require a StorageAccount
        $StorageAccount
    )

    Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"

    Write-Host ""
    Write-Host "Get-ServiceEndpoint -Name $ConnectedServiceName -Context $distributedTaskContext"
    $serviceEndpoint = Get-ServiceEndpoint -Name "$ConnectedServiceName" -Context $distributedTaskContext
    if ($serviceEndpoint -eq $null)
    {
        throw "A Connected Service with name '$ConnectedServiceName' could not be found.  Ensure that this Connected Service was successfully provisioned using services tab in Admin UI."
    }

    $x509Cert = $null
    if ($serviceEndpoint.Authorization.Scheme -eq 'Certificate')
    {
        $subscription = $serviceEndpoint.Data.SubscriptionName
        Write-Host "subscription= $subscription"

        Write-Host "Get-X509Certificate -CredentialsXml <xml>"
        $x509Cert = Get-X509Certificate -ManagementCertificate $serviceEndpoint.Authorization.Parameters.Certificate
        if (!$x509Cert)
        {
            throw "There was an error with the Azure management certificate used for deployment."
        }

        $azureSubscriptionId = $serviceEndpoint.Data.SubscriptionId
        $azureSubscriptionName = $serviceEndpoint.Data.SubscriptionName
        $azureServiceEndpoint = $serviceEndpoint.Url

		$EnvironmentName = "AzureCloud"
		if( $serviceEndpoint.Data.Environment )
        {
            $EnvironmentName = $serviceEndpoint.Data.Environment
        }

        Write-Host "azureSubscriptionId= $azureSubscriptionId"
        Write-Host "azureSubscriptionName= $azureSubscriptionName"
        Write-Host "azureServiceEndpoint= $azureServiceEndpoint"
    }
    elseif ($serviceEndpoint.Authorization.Scheme -eq 'UserNamePassword')
    {
        $username = $serviceEndpoint.Authorization.Parameters.UserName
        $password = $serviceEndpoint.Authorization.Parameters.Password
        $azureSubscriptionId = $serviceEndpoint.Data.SubscriptionId
        $azureSubscriptionName = $serviceEndpoint.Data.SubscriptionName

        Write-Host "Username= $username"
        Write-Host "azureSubscriptionId= $azureSubscriptionId"
        Write-Host "azureSubscriptionName= $azureSubscriptionName"

        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $psCredential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
        
        if(Get-Module Azure)
        {
             Write-Host "Add-AzureAccount -Credential `$psCredential"
             $azureAccount = Add-AzureAccount -Credential $psCredential
        }

        if(Get-module -Name Azurerm.profile -ListAvailable)
        {
             Write-Host "Add-AzureRMAccount -Credential `$psCredential"
             $azureRMAccount = Add-AzureRMAccount -Credential $psCredential
        }

        if (!$azureAccount -and !$azureRMAccount)
        {
            throw "There was an error with the Azure credentials used for deployment."
        }

        if($azureAccount)
        {
            Set-CurrentAzureSubscription -azureSubscriptionId $azureSubscriptionId -storageAccount $StorageAccount
        }

        if($azureRMAccount)
        {
            Set-CurrentAzureRMSubscription -azureSubscriptionId $azureSubscriptionId
        }
    }
    elseif ($serviceEndpoint.Authorization.Scheme -eq 'ServicePrincipal')
    {
        $servicePrincipalId = $serviceEndpoint.Authorization.Parameters.ServicePrincipalId
        $servicePrincipalKey = $serviceEndpoint.Authorization.Parameters.ServicePrincipalKey
        $tenantId = $serviceEndpoint.Authorization.Parameters.TenantId
        $azureSubscriptionId = $serviceEndpoint.Data.SubscriptionId
        $azureSubscriptionName = $serviceEndpoint.Data.SubscriptionName

        Write-Host "tenantId= $tenantId"
        Write-Host "azureSubscriptionId= $azureSubscriptionId"
        Write-Host "azureSubscriptionName= $azureSubscriptionName"

        $securePassword = ConvertTo-SecureString $servicePrincipalKey -AsPlainText -Force
        $psCredential = New-Object System.Management.Automation.PSCredential ($servicePrincipalId, $securePassword)

        $currentVersion =  Get-AzureCmdletsVersion
        $minimumAzureVersion = New-Object System.Version(0, 9, 9)
        $isPostARMCmdlet = Get-AzureVersionComparison -AzureVersion $currentVersion -CompareVersion $minimumAzureVersion

        if($isPostARMCmdlet)
        {
             if(!(Get-module -Name Azurerm.profile -ListAvailable))
             {
                  throw "AzureRM Powershell module is not found. SPN based authentication is failed."
             }

             Write-Host "Add-AzureRMAccount -ServicePrincipal -Tenant $tenantId -Credential $psCredential"
             $azureRMAccount = Add-AzureRMAccount -ServicePrincipal -Tenant $tenantId -Credential $psCredential 
        }
        else
        {
             Write-Host "Add-AzureAccount -ServicePrincipal -Tenant `$tenantId -Credential `$psCredential"
             $azureAccount = Add-AzureAccount -ServicePrincipal -Tenant $tenantId -Credential $psCredential
        }

        if (!$azureAccount -and !$azureRMAccount)
        {
            throw "There was an error with the service principal used for deployment."
        }

        if($azureAccount)
        {
            Set-CurrentAzureSubscription -azureSubscriptionId $azureSubscriptionId -storageAccount $StorageAccount
        }

        if($azureRMAccount)
        {
            Set-CurrentAzureRMSubscription -azureSubscriptionId $azureSubscriptionId -tenantId $tenantId
        }
    }
    else
    {
        throw "Unsupported authorization scheme for azure endpoint = " + $serviceEndpoint.Authorization.Scheme
    }

    if ($x509Cert)
    {
        if(!(Get-Module Azure))
        {
             throw "Azure Powershell module is not found. Certificate based authentication is failed."
        }

        if (Get-RequiresEnvironmentParameter)
        {
            if ($StorageAccount)
            {
                Write-Host "Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate <cert> -CurrentStorageAccountName $StorageAccount -Environment $EnvironmentName"
                Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate $x509Cert -CurrentStorageAccountName $StorageAccount -Environment $EnvironmentName
            }
            else
            {
                Write-Host "Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate <cert> -Environment $EnvironmentName"
                Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate $x509Cert -Environment $EnvironmentName
            }
        }
        else
        {
            if ($StorageAccount)
            {
                Write-Host "Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate <cert> -ServiceEndpoint $azureServiceEndpoint -CurrentStorageAccountName $StorageAccount"
                Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate $x509Cert -ServiceEndpoint $azureServiceEndpoint -CurrentStorageAccountName $StorageAccount
            }
            else
            {
                Write-Host "Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate <cert> -ServiceEndpoint $azureServiceEndpoint"
                Set-AzureSubscription -SubscriptionName $azureSubscriptionName -SubscriptionId $azureSubscriptionId -Certificate $x509Cert -ServiceEndpoint $azureServiceEndpoint
            }
        }

        Set-CurrentAzureSubscription -azureSubscriptionId $azureSubscriptionId -storageAccount $StorageAccount
    }
}

function Get-AzureModuleLocation
{
    #Locations are from Web Platform Installer
    $azureModuleFolder = ""
    $azureX86Location = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
    $azureLocation = "${env:ProgramFiles}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"

    if (Test-Path($azureX86Location))
    {
        $azureModuleFolder = $azureX86Location
    }
     
    elseif (Test-Path($azureLocation))
    {
        $azureModuleFolder = $azureLocation
    }

    $azureModuleFolder
}

function Import-AzurePowerShellModule
{
    # Try this to ensure the module is actually loaded...
    $moduleLoaded = $false
    $azureFolder = Get-AzureModuleLocation

    if(![string]::IsNullOrEmpty($azureFolder))
    {
        Write-Host "Looking for Azure PowerShell module at $azureFolder"
        Import-Module -Name $azureFolder -Global:$true
        $moduleLoaded = $true
    }
    else
    {
        if(Get-Module -Name "Azure" -ListAvailable)
        {
            Write-Host "Importing Azure Powershell module."
            Import-Module "Azure"
            $moduleLoaded = $true
        }

        if(Get-Module -Name "AzureRM" -ListAvailable)
        {
            Write-Host "Importing AzureRM Powershell module."
            Import-Module "AzureRM"
            $moduleLoaded = $true
        }
    }

    if(!$moduleLoaded)
    {
         throw "Windows Azure Powershell (Azure.psd1) and Windows AzureRM Powershell (AzureRM.psd1) modules are not found. Retry after restart of VSO Agent service, if modules are recently installed."
    }
}

function Initialize-AzurePowerShellSupport
{
    param
    (
        [String] [Parameter(Mandatory = $true)]
        $ConnectedServiceName,

        [String] [Parameter(Mandatory = $false)]  #publishing websites doesn't require a StorageAccount
        $StorageAccount
    )

    #Ensure we can call the Azure module/cmdlets
    Import-AzurePowerShellModule

    $minimumAzureVersion = "0.8.10.1"
    $minimumRequiredAzurePSCmdletVersion = New-Object -TypeName System.Version -ArgumentList $minimumAzureVersion
    $installedAzureVersion = Get-AzureCmdletsVersion
    Write-Host "AzurePSCmdletsVersion= $installedAzureVersion"

    $result = Get-AzureVersionComparison -AzureVersion $installedAzureVersion -CompareVersion $minimumRequiredAzurePSCmdletVersion
    if (!$result)
    {
        throw "The required minimum version ($minimumAzureVersion) of the Azure Powershell Cmdlets are not installed."
    }

    # Set UserAgent for Azure
    Set-UserAgent

    # Intialize the Azure subscription based on the passed in values
    Initialize-AzureSubscription -ConnectedServiceName $ConnectedServiceName -StorageAccount $StorageAccount
}
# SIG # Begin signature block
# MIIjhQYJKoZIhvcNAQcCoIIjdjCCI3ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAjLHErWkQVhiJ
# h63kfMHLxaqf1YYraTQRHNVPTTxRuqCCDYEwggX/MIID56ADAgECAhMzAAAB32vw
# LpKnSrTQAAAAAAHfMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAxMjE1MjEzMTQ1WhcNMjExMjAyMjEzMTQ1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC2uxlZEACjqfHkuFyoCwfL25ofI9DZWKt4wEj3JBQ48GPt1UsDv834CcoUUPMn
# s/6CtPoaQ4Thy/kbOOg/zJAnrJeiMQqRe2Lsdb/NSI2gXXX9lad1/yPUDOXo4GNw
# PjXq1JZi+HZV91bUr6ZjzePj1g+bepsqd/HC1XScj0fT3aAxLRykJSzExEBmU9eS
# yuOwUuq+CriudQtWGMdJU650v/KmzfM46Y6lo/MCnnpvz3zEL7PMdUdwqj/nYhGG
# 3UVILxX7tAdMbz7LN+6WOIpT1A41rwaoOVnv+8Ua94HwhjZmu1S73yeV7RZZNxoh
# EegJi9YYssXa7UZUUkCCA+KnAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUOPbML8IdkNGtCfMmVPtvI6VZ8+Mw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDYzMDA5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAnnqH
# tDyYUFaVAkvAK0eqq6nhoL95SZQu3RnpZ7tdQ89QR3++7A+4hrr7V4xxmkB5BObS
# 0YK+MALE02atjwWgPdpYQ68WdLGroJZHkbZdgERG+7tETFl3aKF4KpoSaGOskZXp
# TPnCaMo2PXoAMVMGpsQEQswimZq3IQ3nRQfBlJ0PoMMcN/+Pks8ZTL1BoPYsJpok
# t6cql59q6CypZYIwgyJ892HpttybHKg1ZtQLUlSXccRMlugPgEcNZJagPEgPYni4
# b11snjRAgf0dyQ0zI9aLXqTxWUU5pCIFiPT0b2wsxzRqCtyGqpkGM8P9GazO8eao
# mVItCYBcJSByBx/pS0cSYwBBHAZxJODUqxSXoSGDvmTfqUJXntnWkL4okok1FiCD
# Z4jpyXOQunb6egIXvkgQ7jb2uO26Ow0m8RwleDvhOMrnHsupiOPbozKroSa6paFt
# VSh89abUSooR8QdZciemmoFhcWkEwFg4spzvYNP4nIs193261WyTaRMZoceGun7G
# CT2Rl653uUj+F+g94c63AhzSq4khdL4HlFIP2ePv29smfUnHtGq6yYFDLnT0q/Y+
# Di3jwloF8EWkkHRtSuXlFUbTmwr/lDDgbpZiKhLS7CBTDj32I0L5i532+uHczw82
# oZDmYmYmIUSMbZOgS65h797rj5JJ6OkeEUJoAVwwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWjCCFVYCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAd9r8C6Sp0q00AAAAAAB3zAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgAdp1GtVJ
# YU6rgcrIIARGNB/NYA5cbqqQNL4WNDcVFa0wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBZGGjby+DwiZpKnQg6alLmf/1rHKFsERxLSAZ48pkU
# Bn+Nk2/JUwECGHIsOs8mt7P3ADFK2uolILQ6UUnDxU7Kc3I/zKPRZlIvPJ7fCK/+
# nO9p9RQcNDE4bZr7PPFKBGHETGQG1Sgeal+mQXRDXMSoFZ0RJuuujT7fCRWl00pB
# Bjbo/HhJHqyiR1AKs9v8acaoZNuhT76oQOa2ar4UanCBtU70Q+U9i79jkVn43lFZ
# IpUjxeoygAKu8rKjK4+QCBY11Tfvheft/tIU4FiOsfU5WQyeBLdFyHNZXmQB8XMw
# ZemotRcBglhRFr1ktRngToTM7R4Ijybbq7xtPAJ5x49WoYIS5DCCEuAGCisGAQQB
# gjcDAwExghLQMIISzAYJKoZIhvcNAQcCoIISvTCCErkCAQMxDzANBglghkgBZQME
# AgEFADCCAVAGCyqGSIb3DQEJEAEEoIIBPwSCATswggE3AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILf9GZKh8HHsrnGzqwT0rPmMLrcs+Bl2IcMry7oo
# Ua4XAgZg02Qz9y8YEjIwMjEwNzEzMDk0MDU5LjI5WjAEgAIB9KCB0KSBzTCByjEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046REQ4Qy1FMzM3LTJGQUUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2Wggg48MIIE8TCCA9mgAwIBAgITMwAAAU6Msevt17LjAAAAAAABTjAN
# BgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0y
# MDExMTIxODI2MDFaFw0yMjAyMTExODI2MDFaMIHKMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpERDhDLUUzMzctMkZB
# RTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAIb7m+j1Sv2TucITpqVT2TUC/8PkbRtE
# s5JBEt+Xvr+yInANW+Umz2uyfGZeirZW7/kEJWcCLr1vSdQisk1dBE+vEFvLWQvZ
# ZaOADLg5Y2WFPNhY3xJgsDU6rCO8E2dyvVV6N4cjTXwbV7nDxjCrAGG4r8hqEgIz
# +3xShMEiEo+xsbc0IidzNTkaAd6sbQzKnu6D37wSzqOgCXam7zwZ58eDjxE6cIYC
# +ZvfE+ml2FQfOlLA+GMu8wc+eKVAA3YiNBycCvF0FDcjqWU4QhbAl2iKfYYb8WJU
# zK8r3ZtY4LBlKPjalwFc02yhvRKj3LFEld8dK7JT98yB+tdM6rSGjakCAwEAAaOC
# ARswggEXMB0GA1UdDgQWBBSiNVETJkLj9rLr5+bCaWrapmAZ4TAfBgNVHSMEGDAW
# gBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8v
# Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNUaW1TdGFQQ0Ff
# MjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0YVBDQV8yMDEw
# LTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0G
# CSqGSIb3DQEBCwUAA4IBAQCjiZzIrZKvgWUXlWBORF3U855V5sRYK8mOGzUiptV9
# Il581ZcvmJgvFzZ8mxw17uLzrKtsF+xOGPy69BXuXHQkQa381PqeVSdjHIkHZko3
# Wk8AJwoyYct5dQvoEyuBoT1WXnMlDKvmEZ9roYtB5d6u3/xbErjl+6wA1cWrMQ4H
# ymDDJ2WHFoWv5Htgfx5z74Qmb7IggXq0LWfli9bLiZA0oGQW6TnYXEMqghJDTa63
# HMtWYrfBETdJVtoZDQ6LEXrlzKZU5aYsgQWbKLSYaQjmS8pAGluCXx+g4o2vDQXz
# 5DlSzoB+gnXWtsrkdSbdS2r3vlIrBwBXMAkJ4zphlbmXMIIGcTCCBFmgAwIBAgIK
# YQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcNMjUwNzAxMjE0
# NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0VBDVpQoAgoX7
# 7XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEwRA/xYIiEVEMM
# 1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQedGFnkV+BVLHP
# k0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKxXf13Hz3wV3Ws
# vYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4GkbaICDXoeByw
# 6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEAAaOCAeYwggHi
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7fEYbxTNoWoVt
# VTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0T
# AQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNV
# HR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9w
# cm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEE
# TjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2Nl
# cnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0gAQH/BIGVMIGS
# MIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYBBQUHAgIwNB4y
# IB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUAbQBlAG4AdAAu
# IB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOhIW+z66bM9TG+
# zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS+7lTjMz0YBKK
# dsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlKkVIArzgPF/Uv
# eYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon/VWvL/625Y4z
# u2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOiPPp/fZZqkHim
# bdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/fmNZJQ96LjlX
# dqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCIIYdqwUB5vvfHh
# AN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0cs0d9LiFAR6A
# +xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7aKLixqduWsqdC
# osnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQcdeh0sVV42ne
# V8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+NR4Iuto229Nf
# j950iEkSoYICzjCCAjcCAQEwgfihgdCkgc0wgcoxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkREOEMtRTMzNy0yRkFF
# MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYF
# Kw4DAhoDFQCDy4/EvT/6w74073FYPHlRLxB+AqCBgzCBgKR+MHwxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA5JeXSDAiGA8yMDIx
# MDcxMzEyMzgzMloYDzIwMjEwNzE0MTIzODMyWjB3MD0GCisGAQQBhFkKBAExLzAt
# MAoCBQDkl5dIAgEAMAoCAQACAh6oAgH/MAcCAQACAhHMMAoCBQDkmOjIAgEAMDYG
# CisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEA
# AgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAxr7EdbmhurN0kPykhoeP1F52DQ1Br8wh
# WhLHqgy7jicwdWo0OzqxRi97i2QmlxyZ9sRjMQmA6ZWBhkMvFxim09kuO4Jq2Ed5
# 2dQW0ZAw1bjcRiPtUimJQe+rCnMlz5H1cBqBPdbhkYmAkhjxTcefhqNQrO/2CZgv
# QUitCrjRbz0xggMNMIIDCQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMAITMwAAAU6Msevt17LjAAAAAAABTjANBglghkgBZQMEAgEFAKCCAUowGgYJ
# KoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCh3Spf6v0o
# pMs4VETAnwbet2m1mgLfZUKHE+c+2XV5ITCB+gYLKoZIhvcNAQkQAi8xgeowgecw
# geQwgb0EIAj+DeKYS4uB5zD+uh1CCkTd7zIxK4gCjv7qfePKJS+SMIGYMIGApH4w
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAFOjLHr7dey4wAAAAAA
# AU4wIgQgYmbEFjtdlM8ttuRIWZJrwvl4fPduxzLakhHh2gMkV+UwDQYJKoZIhvcN
# AQELBQAEggEAGcAvTz/kXmTyV/+14ySSiNi17Q4nIeGvzRjkwxaeFIySvzqcRInq
# x9feg+YOzHQkE0Rh0OtD+tzOOT0Znj7R1ZQ2Xz4E3RnRTPC36MOAKijrwX+g4zah
# cLO+kh4iIeoKjIuFvCdj/aQJ7uvTlF4KHcpr+VwwNBZszDbEa5AdeWRXk7BaRyMN
# sQfWO4Vq9ROhotWqUy9mLgwgAUqZbEZ+26xhTI4yYhaK2O/fYbbRVq4VrmQakfml
# M2noCU0TR40fOJqx46ciC+0HGvY+HQ/ufEkWK4nF60s+6f5VeDQXL+Z+TwenI05t
# g6JFKdVj1neWR6anByfFSeuTSY2g0fjYiA==
# SIG # End signature block

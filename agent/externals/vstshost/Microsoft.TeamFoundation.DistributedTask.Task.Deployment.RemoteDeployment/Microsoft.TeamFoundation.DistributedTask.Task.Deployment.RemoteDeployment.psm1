<#
    Microsoft.TeamFoundation.DistributedTask.Task.Deployment.RemoteDeployment.psm1
#>

function Invoke-RemoteDeployment
{    
    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory=$true)]
        [string]$environmentName,
        [string]$adminUserName,
        [string]$adminPassword,
        [string]$protocol,
        [string]$testCertificate,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='TagsBlock')]
        [string]$tags,
        [Parameter(ParameterSetName='MachinesPath')]
        [Parameter(ParameterSetName='MachinesBlock')]
        [string]$machineNames,
        [Parameter(Mandatory=$true, ParameterSetName='TagsPath')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesPath')]
        [string]$scriptPath,
        [Parameter(Mandatory=$true, ParameterSetName='TagsBlock')]
        [Parameter(Mandatory=$true, ParameterSetName='MachinesBlock')]
        [string]$scriptBlockContent,
        [string]$scriptArguments,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$initializationScriptPath,
        [string]$runPowershellInParallel,
        [Parameter(ParameterSetName='TagsPath')]
        [Parameter(ParameterSetName='MachinesPath')]
        [string]$sessionVariables
    )

    Write-Verbose "Entering Remote-Deployment block"
        
    $machineFilter = $machineNames

    # Getting resource tag key name for corresponding tag
    $resourceFQDNKeyName = Get-ResourceFQDNTagKey
    $resourceWinRMHttpPortKeyName = Get-ResourceHttpTagKey
    $resourceWinRMHttpsPortKeyName = Get-ResourceHttpsTagKey

    # Constants #
    $useHttpProtocolOption = '-UseHttp'
    $useHttpsProtocolOption = ''

    $doSkipCACheckOption = '-SkipCACheck'
    $doNotSkipCACheckOption = ''
    $ErrorActionPreference = 'Stop'
    $deploymentOperation = 'Deployment'

    $envOperationStatus = "Passed"

    # enabling detailed logging only when system.debug is true
    $enableDetailedLoggingString = $env:system_debug
    if ($enableDetailedLoggingString -ne "true")
    {
        $enableDetailedLoggingString = "false"
    }

    function Get-ResourceWinRmConfig
    {
        param
        (
            [string]$resourceName,
            [int]$resourceId
        )

        $resourceProperties = @{}

        $winrmPortToUse = ''
        $protocolToUse = ''


        if($protocol -eq "HTTPS")
        {
            $protocolToUse = $useHttpsProtocolOption
        
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTPS", $resourceName)
            }
        }
        elseif($protocol -eq "HTTP")
        {
            $protocolToUse = $useHttpProtocolOption
            
            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmPortToUse = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
        
            if([string]::IsNullOrWhiteSpace($winrmPortToUse))
            {
                throw(Get-LocalizedString -Key "{0} port was not provided for resource '{1}'" -ArgumentList "WinRM HTTP", $resourceName)
            }
        }

        elseif($environment.Provider -ne $null)      #  For standerd environment provider will be null
        {
            Write-Verbose "`t Environment is not standerd environment. Https port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
            $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId (Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpsPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm https port defined, checking for winrm http port"
                    
                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
                   $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId 
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm http port defined
                    $winrmPortToUse = $winrmHttpPort
                    $protocolToUse = $useHttpProtocolOption
                }
            }
            else
            {
                # if resource has winrm https port opened
                $winrmPortToUse = $winrmHttpsPort
                $protocolToUse = $useHttpsProtocolOption
            }
        }
        else
        {
            Write-Verbose "`t Environment is standerd environment. Http port has higher precedence"

            Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"
            $winrmHttpPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpPortKeyName -ResourceId $resourceId
            Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpPortKeyName"

            if ([string]::IsNullOrEmpty($winrmHttpPort))
            {
                Write-Verbose "`t Resource: $resourceName does not have any winrm http port defined, checking for winrm https port"

                   Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"
                   $winrmHttpsPort = Get-EnvironmentProperty -Environment $environment -Key $resourceWinRMHttpsPortKeyName -ResourceId $resourceId
                   Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with resource id: $resourceId(Name : $resourceName) and key: $resourceWinRMHttpsPortKeyName"

                if ([string]::IsNullOrEmpty($winrmHttpsPort))
                {
                    throw(Get-LocalizedString -Key "Resource: '{0}' does not have WinRM service configured. Configure WinRM service on the Azure VM Resources. Refer for more details '{1}'" -ArgumentList $resourceName, "https://aka.ms/azuresetup" )
                }
                else
                {
                    # if resource has winrm https port defined
                    $winrmPortToUse = $winrmHttpsPort
                    $protocolToUse = $useHttpsProtocolOption
                }
            }
            else
            {
                # if resource has winrm http port opened
                $winrmPortToUse = $winrmHttpPort
                $protocolToUse = $useHttpProtocolOption
            }
        }

        $resourceProperties.protocolOption = $protocolToUse
        $resourceProperties.winrmPort = $winrmPortToUse

        return $resourceProperties;
    }

    function Get-SkipCACheckOption
    {
        [CmdletBinding()]
        Param
        (
            [string]$environmentName
        )

        $skipCACheckOption = $doNotSkipCACheckOption
        $skipCACheckKeyName = Get-SkipCACheckTagKey

        # get skipCACheck option from environment
        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"
        $skipCACheckBool = Get-EnvironmentProperty -Environment $environment -Key $skipCACheckKeyName 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $($environment.Name) with key: $skipCACheckKeyName"

        if ($skipCACheckBool -eq "true")
        {
            $skipCACheckOption = $doSkipCACheckOption
        }

        return $skipCACheckOption
    }

    function Get-ResourceConnectionDetails
    {
        param([object]$resource)

        $resourceProperties = @{}
        $resourceName = $resource.Name
        $resourceId = $resource.Id

        Write-Verbose "Starting Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"
        $fqdn = Get-EnvironmentProperty -Environment $environment -Key $resourceFQDNKeyName -ResourceId $resourceId 
        Write-Verbose "Completed Get-EnvironmentProperty cmdlet call on environment name: $environmentName with resource id: $resourceId(Name : $resourceName) and key: $resourceFQDNKeyName"

        $winrmconfig = Get-ResourceWinRmConfig -resourceName $resourceName -resourceId $resourceId
        $resourceProperties.fqdn = $fqdn
        $resourceProperties.winrmPort = $winrmconfig.winrmPort
        $resourceProperties.protocolOption = $winrmconfig.protocolOption
        $resourceProperties.credential = Get-ResourceCredentials -resource $resource	
        $resourceProperties.displayName = $fqdn + ":" + $winrmconfig.winrmPort

        return $resourceProperties
    }

    function Get-ResourcesProperties
    {
        param([object]$resources)

        $skipCACheckOption = Get-SkipCACheckOption -environmentName $environmentName
        [hashtable]$resourcesPropertyBag = @{}

        foreach ($resource in $resources)
        {
            $resourceName = $resource.Name
            $resourceId = $resource.Id
            Write-Verbose "Get Resource properties for $resourceName (ResourceId = $resourceId)"
            $resourceProperties = Get-ResourceConnectionDetails -resource $resource
            $resourceProperties.skipCACheckOption = $skipCACheckOption
            $resourcesPropertyBag.add($resourceId, $resourceProperties)
        }

        return $resourcesPropertyBag
    }

    $RunPowershellJobInitializationScript = {
        function Load-AgentAssemblies
        {
            
            if(Test-Path "$env:AGENT_HOMEDIRECTORY\Agent\Worker")
            {
                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }

                Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\Modules\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\*.dll | % {
                [void][reflection.assembly]::LoadFrom( $_.FullName )
                Write-Verbose "Loading .NET assembly:`t$($_.name)"
                }
            }
            else
            {
                if(Test-Path "$env:AGENT_HOMEDIRECTORY\externals\vstshost")
                {
                    [void][reflection.assembly]::LoadFrom("$env:AGENT_HOMEDIRECTORY\externals\vstshost\Microsoft.TeamFoundation.DistributedTask.Task.LegacySDK.dll")
                }
            }
        }

        function Get-EnableDetailedLoggingOption
        {
            param ([string]$enableDetailedLogging)

            if ($enableDetailedLogging -eq "true")
            {
                return '-EnableDetailedLogging'
            }

            return '';
        }
    }

    $RunPowershellJobForScriptPath = {
        param (
        [string]$fqdn, 
        [string]$scriptPath,
        [string]$port,
        [string]$scriptArguments,
        [string]$initializationScriptPath,
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging,
        [object]$sessionVariables
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "scriptPath = $scriptPath"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "initializationScriptPath = $initializationScriptPath"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
    
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptPath `$scriptPath -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments -InitializationScriptPath `$initializationScriptPath -SessionVariables `$sessionVariables $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $RunPowershellJobForScriptBlock = {
    param (
        [string]$fqdn, 
        [string]$scriptBlockContent,
        [string]$port,
        [string]$scriptArguments,    
        [object]$credential,
        [string]$httpProtocolOption,
        [string]$skipCACheckOption,
        [string]$enableDetailedLogging    
        )

        Write-Verbose "fqdn = $fqdn"
        Write-Verbose "port = $port"
        Write-Verbose "scriptArguments = $scriptArguments"
        Write-Verbose "protocolOption = $httpProtocolOption"
        Write-Verbose "skipCACheckOption = $skipCACheckOption"
        Write-Verbose "enableDetailedLogging = $enableDetailedLogging"

        Load-AgentAssemblies

        $enableDetailedLoggingOption = Get-EnableDetailedLoggingOption $enableDetailedLogging
   
        Write-Verbose "Initiating deployment on $fqdn"
        [String]$psOnRemoteScriptBlockString = "Invoke-PsOnRemote -MachineDnsName $fqdn -ScriptBlockContent `$scriptBlockContent -WinRMPort $port -Credential `$credential -ScriptArguments `$scriptArguments $skipCACheckOption $httpProtocolOption $enableDetailedLoggingOption"
        [scriptblock]$psOnRemoteScriptBlock = [scriptblock]::Create($psOnRemoteScriptBlockString)
        $deploymentResponse = Invoke-Command -ScriptBlock $psOnRemoteScriptBlock
    
        Write-Output $deploymentResponse
    }

    $connection = Get-VssConnection -TaskContext $distributedTaskContext

    # This is temporary fix for filtering 
    if([string]::IsNullOrEmpty($machineNames))
    {
       $machineNames  = $tags
    }

    Write-Verbose "Starting Register-Environment cmdlet call for environment : $environmentName with filter $machineNames"
    $environment = Register-Environment -EnvironmentName $environmentName -EnvironmentSpecification $environmentName -UserName $adminUserName -Password $adminPassword -WinRmProtocol $protocol -TestCertificate ($testCertificate -eq "true")  -Connection $connection -TaskContext $distributedTaskContext -ResourceFilter $machineNames
	Write-Verbose "Completed Register-Environment cmdlet call for environment : $environmentName"
	
    Write-Verbose "Starting Get-EnvironmentResources cmdlet call on environment name: $environmentName"
    $resources = Get-EnvironmentResources -Environment $environment

    if ($resources.Count -eq 0)
    {
      throw (Get-LocalizedString -Key "No machine exists under environment: '{0}' for deployment" -ArgumentList $environmentName)
    }

    $resourcesPropertyBag = Get-ResourcesProperties -resources $resources

    $parsedSessionVariables = Get-ParsedSessionVariables -inputSessionVariables $sessionVariables

    if($runPowershellInParallel -eq "false" -or  ( $resources.Count -eq 1 ) )
    {
        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            . $RunPowershellJobInitializationScript
            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $deploymentResponse = Invoke-Command -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString 
            }

            Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $deploymentResponse
            $status = $deploymentResponse.Status
				
			if ($status -ne "Passed")
			{             
			    if($deploymentResponse.Error -ne $null)
                {
					Write-Verbose (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $deploymentResponse.Error.ToString())
                    $errorMessage = $deploymentResponse.Error.Message
					return $errorMessage					
                }
				else
				{
					$errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
					return $errorMessage
				}
           }
		   
		    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
        }
    }
    else
    {
        [hashtable]$Jobs = @{} 

        foreach($resource in $resources)
        {
            $resourceProperties = $resourcesPropertyBag.Item($resource.Id)
            $machine = $resourceProperties.fqdn
            $displayName = $resourceProperties.displayName
            Write-Host (Get-LocalizedString -Key "Deployment started for machine: '{0}'" -ArgumentList $displayName)

            if($PsCmdlet.ParameterSetName.EndsWith("Path"))
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptPath -ArgumentList $machine, $scriptPath, $resourceProperties.winrmPort, $scriptArguments, $initializationScriptPath, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString, $parsedSessionVariables
            }
            else
            {
                $job = Start-Job -InitializationScript $RunPowershellJobInitializationScript -ScriptBlock $RunPowershellJobForScriptBlock -ArgumentList $machine, $scriptBlockContent, $resourceProperties.winrmPort, $scriptArguments, $resourceProperties.credential, $resourceProperties.protocolOption, $resourceProperties.skipCACheckOption, $enableDetailedLoggingString                 
            }
            
            $Jobs.Add($job.Id, $resourceProperties)
        }
        While (Get-Job)
        {
            Start-Sleep 10 
            foreach($job in Get-Job)
            {
                 if($job.State -ne "Running")
                {
                    $output = Receive-Job -Id $job.Id
                    Remove-Job $Job
                    $status = $output.Status
                    $displayName = $Jobs.Item($job.Id).displayName
                    $resOperationId = $Jobs.Item($job.Id).resOperationId

                    Write-ResponseLogs -operationName $deploymentOperation -fqdn $displayName -deploymentResponse $output
                    Write-Host (Get-LocalizedString -Key "Deployment status for machine '{0}' : '{1}'" -ArgumentList $displayName, $status)
                    if($status -ne "Passed")
                    {
                        $envOperationStatus = "Failed"
                        $errorMessage = ""
                        if($output.Error -ne $null)
                        {
                            $errorMessage = $output.Error.Message
                        }
                        Write-Host (Get-LocalizedString -Key "Deployment failed on machine '{0}' with following message : '{1}'" -ArgumentList $displayName, $errorMessage)
                    }
                }
            }
        }
    }

    if($envOperationStatus -ne "Passed")
    {
         $errorMessage = (Get-LocalizedString -Key 'Deployment on one or more machines failed.')
         return $errorMessage
    }

}
# SIG # Begin signature block
# MIIjgwYJKoZIhvcNAQcCoIIjdDCCI3ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDvZ3uXMKhqjxqP
# pD9BYnyXygrXbhnvSUzwcypxeAztfKCCDYEwggX/MIID56ADAgECAhMzAAAB32vw
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWDCCFVQCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAd9r8C6Sp0q00AAAAAAB3zAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg+93ZpIXY
# Snfs+4KcVbt7ajHRyLO4HxVrM+T768vrJ/QwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCB92cHQaAkwbeLvfyvyBlAdRuUiVIeKxSEnL6aqam/
# i8n9wX8BBGUuXRFz0D+7SmIJcPjtHw8i4OTOnmVRUxiecn/TGQKLNiqiKrVcUJTX
# rcZYkekrikGfDnwCWbvxdzQMWiPGTfAu3kmyHPYelsS9adCftrslRnQ6zny72dB0
# mPNGOJW2ASuvsdBOgR24vht4wvv5b4d1Kjo8oyxjk0vDpWJ27SqxjmRoEdu8Sgry
# Y8Oylz5bqIpVTuU/Rizk7uubKLfJ7M9P5MZiryStD/K2bSSGvCYPThbwX0pPAamH
# J0JD3Ev2qrVwy7kThs8VTD5Xuof7hg7s7wFBTwJozLfBoYIS4jCCEt4GCisGAQQB
# gjcDAwExghLOMIISygYJKoZIhvcNAQcCoIISuzCCErcCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMhbufqkouj9iOR9lEBfYY3CYo5/mSim3uU422fG
# V/rUAgZg0RTfU5AYEzIwMjEwNzEzMDk0MTAwLjEwMlowBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjhBODItRTM0Ri05RERBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIOOTCCBPEwggPZoAMCAQICEzMAAAFLT7KmSNXkwlEAAAAAAUsw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjAxMTEyMTgyNTU5WhcNMjIwMjExMTgyNTU5WjCByjELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046OEE4Mi1FMzRGLTlE
# REExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQChNnpQx3YuJr/ivobPoLtpQ9egUFl8
# THdWZ6SAKIJdtP3L24D3/d63ommmjZjCyrQm+j/1tHDAwjQGuOwYvn79ecPCQfAB
# 91JnEp/wP4BMF2SXyMf8k9R84RthIdfGHPXTWqzpCCfNWolVEcUVm8Ad/r1LrikR
# O+4KKo6slDQJKsgKApfBU/9J7Rudvhw1rEQw0Nk1BRGWjrIp7/uWoUIfR4rcl6U1
# utOiYIonC87PPpAJQXGRsDdKnVFF4NpWvMiyeuksn5t/Otwz82sGlne/HNQpmMzi
# gR8cZ8eXEDJJNIZxov9WAHHj28gUE29D8ivAT706ihxvTv50ZY8W51uxAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQUUqpqftASlue6K3LePlTTn01K68YwHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEAFtq51Zc/O1AfJK4tEB2Nr8bGEVD5qQ8l8gXIQMrM
# ZYtddHH+cGiqgF/4GmvmPfl5FAYh+gf/8Yd3q4/iD2+K4LtJbs/3v6mpyBl1mQ4v
# usK65dAypWmiT1W3FiXjsmCIkjSDDsKLFBYH5yGFnNFOEMgL+O7u4osH42f80nc2
# WdnZV6+OvW035XPV6ZttUBfFWHdIbUkdOG1O2n4yJm10OfacItZ08fzgMMqE+f/S
# TgVWNCHbR2EYqTWayrGP69jMwtVD9BGGTWti1XjpvE6yKdO8H9nuRi3L+C6jYntf
# aEmBTbnTFEV+kRx1CNcpSb9os86CAUehZU1aRzQ6CQ/pjzCCBnEwggRZoAMCAQIC
# CmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIx
# NDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF
# ++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRD
# DNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSx
# z5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1
# rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16Hgc
# sOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB
# 4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCB
# kjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQe
# MiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQA
# LiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUx
# vs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GAS
# inbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1
# L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWO
# M7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4
# pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45
# V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x
# 4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEe
# gPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKn
# QqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp
# 3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvT
# X4/edIhJEqGCAsswggI0AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4QTgyLUUzNEYtOURE
# QTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAkToz97fseHxNOUSQ5O/bBVSF+e6ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOSXQlAwIhgPMjAy
# MTA3MTMwNjM2MDBaGA8yMDIxMDcxNDA2MzYwMFowdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA5JdCUAIBADAHAgEAAgIO9DAHAgEAAgIRTzAKAgUA5JiT0AIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBBQUAA4GBAAZCAtc5a8nw12ylA0ne9QTvJ+JjgV8J4enB
# 1TLrLIxrKuPOnokJqxJDIY1tMMdxInJDRMZNTpNCX8/EgVvRAdKzoXpFGr1pDozO
# eag9hXcyKP5Vx48kez8JZKbfUjXNoR7hVL59W+0cehMAH9z3iKdB8zIikyKNnfR2
# 5+pJY7HvMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAFLT7KmSNXkwlEAAAAAAUswDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgp09oQLP+G38W
# J8PPiJ1ENRea2yXjWL49H4TD8+gKmgQwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHk
# MIG9BCBr9u6EInnsZYEts/Fj/rIFv0YZW1ynhXKOP2hVPUU5IzCBmDCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABS0+ypkjV5MJRAAAAAAFL
# MCIEIJ2MLNIpb0m1Jqg3+T6o/hYpqJh2EMQxrqgYHm0v4fByMA0GCSqGSIb3DQEB
# CwUABIIBAFyl1Zxz5o4aJ7/CLy88YQ+k/ln2fOwHpcq9z/EZza7Vh7+MsKrwjAfC
# 1IlkdyNn/AS0DZhUu564pwbPEuE9+PbyVUC52EMhQdksWNQsDFAmMEc3N5Kt+m33
# 3CSTkmiAqr0RM0ylcsgHuuDCIVRG8JsIYVvgBkXPspHpFgEBiSbrUTF10zflmC3t
# tjRV2gxelDoJI8PcJIoaEkByrLI8mo54VkAxFkwQrKpDlxEDs815cmAuCETFs7yG
# L9rTanMVvH4plHcglQWOzqI75SfhqqbSgoSkuQoL8DD6cgX9lmCW7+fsa9INCJY3
# YNmjou3vMJuNiAEa1cAfB2OaQWuPK+8=
# SIG # End signature block

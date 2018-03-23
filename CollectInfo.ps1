param([Parameter(Mandatory=$true)][String]$ContainerId,
      [Parameter(Mandatory=$true)][String]$SiteName,
      [Parameter(Mandatory=$false)][String[]]$Hosts)

# Constants
$NumberOfAccessLogFilesToCollect = 4
$ContainerHostLogFileDestination = "Host"
$HostErrorFile = "CollectInfo-Host.err"

function RunMicrosoftsHealthcheck {
    Start-Process -NoNewWindow `
                    -Wait `
                    -FilePath powershell.exe `
                    -ArgumentList "-Command `"& { Invoke-WebRequest https://aka.ms/Debug-ContainerHost.ps1 -UseBasicParsing | Invoke-Expression }`"" `
                    -RedirectStandardError .\$HostErrorFile `
                    -RedirectStandardOutput .\Debug-ContainerHost.out                
}

function CollectContainerInformation {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    If([String]::IsNullOrEmpty($ContainerId)) {
        Write-Error "The container ID is null or empty. Please provide the container ID using -ContainerId"
    } else {
        Start-Process -NoNewWindow `
                        -Wait `
                        -FilePath docker.exe `
                        -ArgumentList "inspect $ContainerId" `
                        -RedirectStandardError .\$HostErrorFile `
                        -RedirectStandardOutput .\DockerIspect$ContainerId.out

        Start-Process -NoNewWindow `
                        -Wait `
                        -FilePath docker.exe `
                        -ArgumentList "logs $ContainerId" `
                        -RedirectStandardError .\$HostErrorFile `
                        -RedirectStandardOutput .\DockerLogs$ContainerId.out
    }
}

function HostRoutingInformation {
    ipconfig /all | Out-File -FilePath RoutingInformation.out
    route print | Out-File -FilePath RoutingInformation.out -Append
}

function IISUrlRewriteRules {
    param(
        [Parameter(mandatory=$true)][String]$SiteName
    )

    # Get IIS rewrite rules for the site
    $rewriteRules = Get-WebConfigurationProperty -PSPath "iis:\sites\$SiteName" -Name "." -Filter "system.webServer/rewrite/rules"

    # Write IIS rules to file
    ConvertTo-Json $rewriteRules.Collection | Out-File -FilePath .\IISRewriteRules.out
}

function GetSiteAccessLogs {
    param(
        [Parameter(mandatory=$true)][String]$SiteName
    )

    # Get the site information
    $siteInfo = Get-WebConfigurationProperty -PSPath "iis:\Sites" -Name "." -Filter "system.applicationHost/sites/site" | Where-Object { $_.name -like $SiteName}

    # Get the access logs for the site
    # PowerShell isn't able to handle %environment variables% so we have to replace them with $env:environmentVariable 
    $logPath = "Resolve-Path $($siteInfo.logFile.directory)\W3SVC$($siteInfo.id)" -Replace "%(\w+)%", '$env:$1'
    $logFiles = Invoke-Expression $logPath | Get-ChildItem | Sort-Object -Descending -Property LastWriteTime | Select-Object -first $NumberOfAccessLogFilesToCollect
    
    # Create folder for the access logs
    New-Item -Path .\IISAccessLogs -ItemType directory -Force | Out-Null

    # Copy the files to the troubleshooting folder
    foreach($logFile in $logFiles) {
        Copy-Item $logFile.FullName -Destination .\IISAccessLogs
    }
}

function CollectIISConfigurations {
    param(
        [Parameter(mandatory=$true)][String]$SiteName
    )

    If([String]::IsNullOrEmpty($SiteName)) {
        Write-Error "The site name is null or empty. Please provide the site name using -SiteName."
    } else {
        IISUrlRewriteRules -SiteName $SiteName

        GetSiteAccessLogs -SiteName $SiteName
    }
}

function Get-ContainerHostInfo {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId,
        [Parameter(mandatory=$true)][String]$SiteName
    )

    Write-Host "Collecting Container Host information"

    $Destination = $(Join-Path -Path "." -ChildPath $ContainerHostLogFileDestination)

    # Create the directory where we will save all the Container Host information
    New-Item -Path $Destination -ItemType directory -Force | Out-Null

    Set-Location $Destination

    Write-Host "   Collecting Microsoft's Checking for common problems script"
    RunMicrosoftsHealthcheck

    Write-Host "   Collecting container information host side"
    CollectContainerInformation -ContainerId $ContainerId

    Write-Host "   Collecting host routing information" 
    HostRoutingInformation

    Write-Host "   Collecting IIS configuration information and logs"
    CollectIISConfigurations -SiteName $SiteName

    Set-Location .\..
}

# Constants
$ContainerLogFileDestination = "Container"
$IISLogFilesDirectory = "IISLogFiles"
$ContainerErrorFile = "CollectInfo-Container.err"

function Get-ContainerEventLog {
    param(
        [Parameter(Mandatory=$true)][String]$ContainerId
    )

    $Command = ""
    $Command = $Command + "foreach (`$entry in (Get-EventLog -Logname Application)) {`n"
    $Command = $Command + "    Write-Output '------------'`n"
    $Command = $Command + "    Write-Output `"EntryType:      `$(`$entry.EntryType)`"`n"
    $Command = $Command + "    Write-Output `"TimeGenerated:  `$(`$entry.TimeGenerated)`"`n"
    $Command = $Command + "    Write-Output `"TimeWritten:    `$(`$entry.TimeWritten)`"`n"
    $Command = $Command + "    Write-Output `"Source:         `$(`$entry.Source)`"`n"
    $Command = $Command + "    Write-Output 'Message:'`n"
    $Command = $Command + "    Write-Output `$entry.Message`n"
    $Command = $Command + "}"
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\EventLog$ContainerId.out
}

function Test-ContainerConnection {
    param(
        [Parameter(Mandatory=$true)][String]$ContainerId,
        [Parameter(Mandatory=$true)][String[]]$Hosts
    )

    $Command = ""
    foreach ($hst in $Hosts) {
        $Hostname, $Port = $hst.Split(":")
        $Command = $Command + "`n" + "Test-NetConnection -ComputerName $Hostname -Port $Port"
    }
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\CheckConnection$ContainerId.out
    
}

function Get-ApplicationConfiguration {
    param(
        [Parameter(Mandatory=$true)][String]$ContainerId
    )

    $Command = ""
    # Get the appSettings.config from the different modules of the application
    $Command = $Command + "foreach (`$config in (Get-childItem -Path C:\modules -Filter appSettings.config -Recurse)) {`n"
    $Command = $Command + "    Write-Output `$config.FullName`n"
    $Command = $Command + "    Get-Content `$config.FullName`n"
    $Command = $Command + "}`n"
    # Get the Application Scheduler appSettings.config
    $Command = $Command + "Write-Output 'C:\bin\ApplicationScheduler\appSettings.config'`n"
    $Command = $Command + "Get-Content C:\bin\ApplicationScheduler\appSettings.config"
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\AppSettings$ContainerId.out 
}

function Get-ContainerProcesses {
    param(
        [Parameter(Mandatory=$true)][String]$ContainerId
    )

    $Command = "Get-Process"
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\ContainerProcesses$ContainerId.out
}

function Get-IISAccessLogs {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId,
        [Parameter(mandatory=$true)][String]$LogPath
    )

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "cp", "$($ContainerId):C:\inetpub\logs\LogFiles\W3SVC1", $LogPath `
                  -RedirectStandardError .\$ContainerErrorFile
}

function Get-ContainerInfo{
    param(
        [Parameter(mandatory=$true)][String]$ContainerId,
        [Parameter(Mandatory=$false)][String[]]$Hosts
    )

    Write-Host "Collecting Container information"

    # Create the directory where we will save all the Container information
    $Destination = Join-Path -Path "." -ChildPath $ContainerLogFileDestination
    New-Item -Path $Destination -ItemType directory -Force | Out-Null

    Set-Location $Destination

    # Create the directory where we will save the IIS LogFiles
    $IISLogFiles = Join-Path -Path "." -ChildPath $IISLogFilesDirectory
    New-Item -Path $IISLogFiles -ItemType directory -Force | Out-Null

    Write-Host "   Get container application event log"
    Get-ContainerEventLog -ContainerId $ContainerId

    Write-Host "   Get application configuration"
    Get-ApplicationConfiguration -ContainerId $ContainerId

    Write-Host "   Get the running process"
    Get-ContainerProcesses -ContainerId $ContainerId

    if($Hosts.Length -gt 0) {
        Write-Host "   Test connections from container"
        Test-ContainerConnection -ContainerId $ContainerId -Hosts $Hosts
    }

    Write-Host "   Get IIS access logs"
    Get-IISAccessLogs -ContainerId $ContainerId -LogPath $IISLogFiles

    Set-Location .\..
}

Get-ContainerHostInfo -ContainerId $ContainerId -SiteName $SiteName
Get-ContainerInfo -ContainerId $ContainerId -Hosts $Hosts

Compress-Archive -Path .\* -CompressionLevel Optimal -DestinationPath .\CollectInfo.zip -Force
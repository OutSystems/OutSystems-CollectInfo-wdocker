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
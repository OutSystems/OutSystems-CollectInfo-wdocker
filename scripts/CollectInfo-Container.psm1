# Constants
$ContainerLogFileDestination = "Container"
$IISLogFilesDirectory = "IISLogFiles"
$ContainerErrorFile = "CollectInfo-Container.err"

function ConvertTo-EncodedCommand {
    param(
        [Parameter(mandatory=$true)][String]$Command
    )
    
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    return [Convert]::ToBase64String($Bytes)
}

function Enable-ContainerHwcAccessLogs {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    $Command =
@'
    $xml = [xml](Get-Content C:\Users\ContainerAdministrator\tmp\config\ApplicationHost.config)
    $xml.configuration.'system.webServer'.httpLogging[0].SetAttribute('dontLog', 'false')
    $xml.Save('C:\Users\ContainerAdministrator\tmp\config\ApplicationHost.config')
'@

    $EncodedCommand = ConvertTo-EncodedCommand $Command

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\EventLog$ContainerId.out
    
}

function Disable-ContainerHwcAccessLogs {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    $Command =
@'
    $xml = [xml](Get-Content C:\Users\ContainerAdministrator\tmp\config\ApplicationHost.config)
    $xml.configuration.'system.webServer'.httpLogging[0].SetAttribute('dontLog', 'true')
    $xml.Save('C:\Users\ContainerAdministrator\tmp\config\ApplicationHost.config')
'@

    $EncodedCommand = ConvertTo-EncodedCommand $Command

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\EventLog$ContainerId.out
}

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
    
    $EncodedCommand = ConvertTo-EncodedCommand $Command

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
    
    $EncodedCommand = ConvertTo-EncodedCommand $Command

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

    $EncodedCommand = ConvertTo-EncodedCommand $Command

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
    $EncodedCommand = ConvertTo-EncodedCommand $Command

    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId, "powershell", "-encodedCommand", $EncodedCommand `
                  -RedirectStandardError .\$ContainerErrorFile `
                  -RedirectStandardOutput .\ContainerProcesses$ContainerId.out
}


function Get-ContainerHwcAccessLogs {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId,
        [Parameter(mandatory=$true)][String]$LogPath
    )

    Start-Process -NoNewWindow `
                    -Wait `
                    -FilePath docker.exe `
                    -ArgumentList "cp", "$($ContainerId):C:\Users\ContainerAdministrator\tmp\LogFiles", $LogPath `
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

    Write-Host "   Get Hwc access logs"
    Get-ContainerHwcAccessLogs -ContainerId $ContainerId -LogPath $IISLogFiles

    Set-Location .\..
}
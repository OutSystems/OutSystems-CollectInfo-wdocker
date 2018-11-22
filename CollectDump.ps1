param(
    [Parameter(mandatory=$true)][String]$ContainerId
)

# Download procdump tool from https://docs.microsoft.com/en-us/sysinternals/downloads/procdump
# Constants
$ProcDumpFileName = "Procdump.zip"
$ContainerErrorFile = "CollectDump-Container.err"

function HouseKeeping {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    Write-Host "Doing some housekeeping, removing copied files on container"
    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId ,"powershell", "-command", "& { rm .\procdump.exe; rm .\hwc.dmp }" `
                  -RedirectStandardError .\$ContainerErrorFile
				  
	Write-Host "Removing procdump folder"
	rm -Recurse $(Join-Path -Path $PSScriptRoot -ChildPath "procdump")
}

function Invoke-ProcDumpInContainer {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    Write-Host "Running procdump utility tool in $($ContainerId) of process hwc.exe"
    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "exec", $ContainerId ,"powershell", "-command", "c:\procdump -accepteula -ma hwc.exe hwc.dmp" `
                  -RedirectStandardError .\$ContainerErrorFile
}

function Get-DumpFromContainer {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    Write-Host "Getting dump from container to hwc.dmp"
    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "cp", "$($ContainerId):C:\hwc.dmp", "." `
                  -RedirectStandardError .\$ContainerErrorFile
}

function Copy-ProcDumpToContainer {
    param(
        [Parameter(mandatory=$true)][String]$ContainerId
    )

    Write-Host "Copying procdump utility tool to container $($ContainerId)"
    Start-Process -NoNewWindow `
                  -Wait `
                  -FilePath docker.exe `
                  -ArgumentList "cp", ".\procdump\procdump.exe", "$($ContainerId):C:\" `
                  -RedirectStandardError .\$ContainerErrorFile
}


Add-Type -AssemblyName System.IO.Compression.FileSystem

If (Test-Path $ProcDumpFileName)  {
    Write-Host "Extracting zip into procdump folder"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($(Join-Path -Path $PSScriptRoot -ChildPath $ProcDumpFileName), $(Join-Path -Path $PSScriptRoot -ChildPath "procdump"))
} else {
    Write-Host "Procdump.zip utility not found, please download procdump tool from https://docs.microsoft.com/en-us/sysinternals/downloads/procdump" 
}   

Copy-ProcDumpToContainer -ContainerId $ContainerId
Invoke-ProcDumpInContainer -ContainerId $ContainerId
Get-DumpFromContainer -ContainerId $ContainerId
HouseKeeping -ContainerId $ContainerId
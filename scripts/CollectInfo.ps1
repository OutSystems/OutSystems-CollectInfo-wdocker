param([Parameter(Mandatory=$true)][String]$ContainerId,
      [Parameter(Mandatory=$true)][String]$SiteName,
      [Parameter(Mandatory=$false)][String[]]$Hosts)

Import-Module $(Join-Path -Path "." -ChildPath "CollectInfo-Host.psm1") -Force
Import-Module $(Join-Path -Path "." -ChildPath "CollectInfo-Container.psm1") -Force

Get-ContainerHostInfo -ContainerId $ContainerId -SiteName $SiteName
Get-ContainerInfo -ContainerId $ContainerId -Hosts $Hosts

Compress-Archive -Path .\* -CompressionLevel Optimal -DestinationPath .\CollectInfo.zip -Force
param(
    [Parameter(Mandatory=$true)][String]$MainScript
)

$scriptsImported = @()

function Get-ImportFile {
    param(
        [Parameter(Mandatory=$true)][String]$string
    )
}

function Get-ProcessedFile {
    param (
        [Parameter(Mandatory=$true)][String]$ScriptFile
    )
    $script = ""

    if($scriptsImported.Contains($ScriptFile)) {
        return $script
    }

    $scriptsImported.Add($ScriptFile)

    foreach ($line in Get-Content $ScriptFile) {
        if($line | Select-String -Pattern "Import-Module") {
            $importFile = Get-ImportFile -import $line
            $line = Get-ProcessedFile -ScriptFile $importFile
        }
        $script = $script + "`n" + $line
    }

    return $script
}

$outputScript = ""

$outputScript = Get-ProcessedFile -ScriptFile $(Join-Path -Path "." -ChildPath $MainScript)

$outputScript | Out-File -FilePath ..\$MainScript
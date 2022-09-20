#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

if ($IsWindows) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# aliases
$PathSeperator = if ($IsWindows) { '\' } else { '/' }
$TempDirectory = "$HOME$($PathSeperator)Temp"
$TranscriptDirectory = "$TempDirectory$($PathSeperator)Transcript"
$ProfileDirectory = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts) # Not sure if this works on linux


. "$PSScriptRoot\Common\aliases.ps1"
. "$PSScriptRoot\Common\git.ps1"
. "$PSScriptRoot\Common\functions.ps1"
. "$PSScriptRoot\Common\personalization.ps1"
. "$PSScriptRoot\Common\stackexchange.ps1"

if (-not (Test-Path -Path $TempDirectory)) {
    New-Item -ItemType Directory -Path $TempDirectory -Force
}

if (-not (Test-Path -Path $TranscriptDirectory)) {
    New-Item -ItemType Directory -Path $TranscriptDirectory -Force
}

if (-Not (Test-Path -Path "$ProfileDirectory\Settings")) {
    New-Item -ItemType Directory -Path "$ProfileDirectory\Settings" -Force
}

# Set any default settings.clixml here
$DefaultValues = @{
    'TranscriptEnabled' = $false
}

foreach ($Setting in $DefaultValues.GetEnumerator()) {
    $SettingFile = "$ProfileDirectory\Settings\$($Setting.Key)-$($env:COMPUTERNAME).clixml"
    if (-Not (Test-Path -Path $SettingFile)) {
        $Setting.Value | Export-Clixml -Path $SettingFile
    }
}

Set-Location $HOME

Clear-Transcript

if ((Import-Clixml -Path "$ProfileDirectory\Settings\TranscriptEnabled-$($env:COMPUTERNAME).clixml")) {
    $TranscriptFileName = "Transcript-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $TranscriptPath = "$TranscriptDirectory$PathSeperator$TranscriptFileName"
    Start-Transcript -Path $TranscriptPath
}
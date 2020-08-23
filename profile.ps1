#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

if ($IsWindows) {
    # Force TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$TranscriptDirectory = "C:\Temp\Transcript"
$ProfileDirectory = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts)

. "$PSSCriptRoot\Common\aliases.ps1" # Always load aliases first
. "$PSScriptRoot\Common\git.ps1"
. "$PSSCriptRoot\Common\functions.ps1"
. "$PSSCriptRoot\Common\personalization.ps1"

# First time setup (or setup if stuff has been moved/removed/etc)

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
    $Setting.Value | Export-Clixml -Path "$ProfileDirectory\Settings\$($Setting.Key).clixml"
}

Set-Location $HOME

Clear-Transcripts

if ((Import-Clixml -Path "$ProfileDirectory\Settings\TranscriptEnabled.clixml")) {
    $TranscriptFileName = "Transcript-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $TranscriptPath = "C:\Temp\Transcript\$TranscriptFileName"
    Start-Transcript -Path $TranscriptPath
}
#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

$TranscriptDirectory = "C:\Temp\Transcript" # This will need tweaking for linux
$ProfileDirectory = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts) # Not sure if this works on linux

. "$PSSCriptRoot\Common\aliases.ps1" # Always load aliases first
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
    $SettingFile = "$ProfileDirectory\Settings\$($Setting.Key).clixml"
    if (-Not (Test-Path -Path $SettingFile)) {
        $Setting.Value | Export-Clixml -Path $SettingFile
    }
}

Set-Location $HOME

Clear-Transcripts

if ((Import-Clixml -Path "$ProfileDirectory\Settings\TranscriptEnabled.clixml")) {
    $TranscriptFileName = "Transcript-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $TranscriptPath = "C:\Temp\Transcript\$TranscriptFileName"  # Tweaked for linux
    Start-Transcript -Path $TranscriptPath
}
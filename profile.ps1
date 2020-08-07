#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

# aliases
$PathSeperator = if ($IfWindows) { '\' } else { '/' }
$TempDirectory = "$HOME$($PathSeperator)Temp"
$TranscriptDirectory = "$TempDirectory$($PathSeperator)Transcript"
$ProfileDirectory = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts) # Not sure if this works on linux

. "$PSSCriptRoot\Common\functions.ps1"
. "$PSSCriptRoot\Common\personalization.ps1"

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
    $TranscriptPath = "$TranscriptDirectory$PathSeperator$TranscriptFileName"
    Start-Transcript -Path $TranscriptPath
}
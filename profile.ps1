#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

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

    # Initialize any settings with default values here.
}




Set-Location $HOME

Clear-Transcripts
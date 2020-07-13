#Requires -PSEdition Core
#Requires -Modules posh-git, oh-my-posh

. "$PSSCriptRoot\Common\aliases.ps1" # Load aliases first, global variables can go here.
. "$PSSCriptRoot\Common\functions.ps1"
. "$PSSCriptRoot\Common\personalization.ps1"

if (-not (Test-Path -Path $TranscriptDirectory)) {
    New-Item -ItemType Directory -Path $TranscriptDirectory -Force
}

Set-Location $HOME

Clear-Transcripts
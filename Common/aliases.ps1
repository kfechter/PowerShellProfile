# global variables
$global:IsWindowsTerminal = [bool]($env:WT_Session)
$global:ProfileDirectory = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts)
$global:TempDirectory = 'C:\Temp'
$global:TranscriptDirectory = "$TempDirectory\Transcript"
$global:TranscriptFileName = "Transcript-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
$global:TranscriptFullPath = "$TranscriptDirectory\$TranscriptFileName"


# aliases

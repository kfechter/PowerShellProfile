$ProfileDataPath = [IO.Path]::Combine($ProfileDirectory, 'Data')
$AdjectiveFile = [IO.Path]::Combine($ProfileDataPath, 'Adjectives.txt')
$NounFile = [IO.Path]::Combine($ProfileDataPath, 'Nouns.txt')

function Test-PendingReboot {
    <#
.SYNOPSIS
Checks if a machine (Windows or Linux) needs a reboot

.DESCRIPTION
Checks if the local computer needs a reboot. On Linux, checks for the presence of /var/run/reboot-required. On Windows,
checks several registry entries and wmi for reboot flags.

.EXAMPLE
PS> Test-PendingReboot
True
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'Catch here does not need to throw, as it is handled accordingly')]
    param()

    if ($IsLinux) {
        return Test-Path "/var/run/reboot-required"
    }
    elseif ($IsWindows) {
        if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
        if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
        try {
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if (($null -ne $status) -and $status.RebootPending) {
                return $true
            }
        }
        catch {}
        return $false
    }
    else {
        Write-Warning "This operating system is not supported. Cannot determine pending reboot status."
        return $False
    }
}

if ((Get-Alias -Name 'ai' -ErrorAction Ignore).count -ne 0) {
    function Show-AssemblyInformation {
        <#
.SYNOPSIS
Shows the Assembly Information for a .NET assembly.

.DESCRIPTION
If Assembly Information is installed, run it with the specified assembly path

.EXAMPLE
PS> Show-AssemblyInformation -AssemblyPath C:\TEMP\Test.dll
#>
        param([Parameter(Mandatory = $true)][string]$AssemblyPath)

        & ai $AssemblyPath
    }
}

function Test-AdminPrivilege {
    <#
.SYNOPSIS
Checks if a session is running as admin

.DESCRIPTION
Returns true if the user is running powershell as admin, or false if they are not.

.EXAMPLE
PS> Test-AdminPrivilege
False
#>
    $isAdminPowerShell = $false

    if ($IsWindows) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdminPowerShell = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        # EUID eq 0 (i think)
    }

    return $isAdminPowerShell
}

function ConvertFrom-Base64 {
    <#
.SYNOPSIS
Converts a base64 encoded string to the ASCII representation

.DESCRIPTION
Takes in a base64 encoded string and decodes it back into the ASCII representation

.PARAMETER Text
The encoded Text to convert back

.EXAMPLE
ConvertFrom-Base64 -Text SGFoYSBCdXR0cyE=
Haha Butts!
#>

    param(
        [Parameter(Mandatory = $true)][string]$Text
    )

    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Text))
}

function Get-Weather {
    <#
.SYNOPSIS
Gets the weather for the specified city.
.DESCRIPTION
Gets the weather for the specified city, or if none is provided, the default.
.PARAMETER City
Name of the city to get the weather for
.PARAMETER DetailLevel
The detail level to request from the API
0 - Current Weather Only
1 - Current Weather and Today's Forecast
2 - Current Weather, Today's Forecast, and Tomorrow's Forecast
.EXAMPLE
Get-Weather -City Dayton -DetailLevel 1
#>

    param(
        [string]$City = 'Cincinnati',
        [ValidateSet(0, 1, 2)][int]$DetailLevel = 0
    )

    $url = "https://wttr.in/{0}?{1}FT" -f $City, $DetailLevel
    (Invoke-WebRequest -Uri $url -UserAgent 'Curl').Content
}

function Test-Transcription {
    <#
    .SYNOPSIS
        This function will test to see if the current system is transcribing.

    .DESCRIPTION
        This function will test to see if the current system is transcribing, the current transcript will be stopped and restarted with information added to the transcript to show that the log was tested, then reutrn a boolean value.
    .INPUTS
        None

    .OUTPUTS
        Boolean

    .NOTES
        NAME:	Test-Transcribing.ps1
        AUTHOR:	Darryl Kegg
        DATE:	01 October, 2015
        EMAIL:	dkegg@microsoft.com

        VERSION HISTORY:
        1.0 01 October, 2015    Initial Version


        THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED �AS IS� WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
        PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
    #>

    [CmdletBinding(SupportsShouldProcess = $True)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'Catch here does not need to throw, as it is handled accordingly')]
    param()

    Write-Verbose 'Running function TEST-TRANSCRIBING....'
    Write-Verbose 'Set Boolean value to false by default'
    $IsTranscribing = $false

    Write-Information 'Testing to see if powershell is transcribing.  If so, we will stop and re-start transcription'

    Write-Verbose 'Now we test to see if transcribing is in progress'
    $stopTest = try { Stop-transcript -ErrorAction stop } catch {}

    if (!$stopTest) { write-Verbose 'No Transcription was started, we do nothing.' }

    if ($stopTest -and $stoptest.Contains('not been started')) { Write-Verbose 'No Transcription was started, we do nothing.' }

    if ($stopTest -and $stoptest.Contains('output file')) {
        Write-Verbose 'A running transcript was found, resuming...'
        Start-Transcript -path $stoptest.Split(' ')[$stoptest.Split(' ').count - 1] -append | out-null
        Write-Information 'Stopped and restarted the transcription as part of the TEST-TRANSCRIBING function'
        $IsTranscribing = $True
    }

    Write-Verbose "Returning the value of $IsTranscribing to the calling script"
    Return $IsTranscribing
}

function Switch-Transcript {
    <#
.SYNOPSIS
Turns powershell transcripting on or off.

.DESCRIPTION
Gets the current state of transcription, and then either enables it or disables it. Stores the current setting
in the Profile ./Settings/ Directory as a clixml.

.EXAMPLE
PS> Switch-Transcript
Transcription is now Enabled
#>

    $Transcript = Test-Transcription

    $TranscriptFileName = "Transcript-$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $TranscriptPath = "C:\Temp\Transcript\$TranscriptFileName"

    if ($Transcript) {
        Write-Output "Transcription is now Disabled"
        Stop-Transcript
    }
    else {
        Write-Output "Transcription is now Enabled"
        Start-Transcript -Path $TranscriptPath
    }

    $TranscriptSettingsRootPath = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts)
    (-Not $Transcript) | Export-Clixml -Path "$TranscriptSettingsRootPath\Settings\TranscriptEnabled.clixml"
}

function Clear-Transcripts {
    <#
.SYNOPSIS
Clears transcripts older than 30 days.

.DESCRIPTION
Removes all transcript text files older than 30 days from the profile transcript directory.

.EXAMPLE
PS> Clear-Transcripts
WARNING: Removing Transcripts older than 30 days
VERBOSE: Performing the operation "Remove File" on target "C:\Temp\Transcript\Transcript-20200726_003403.txt".
#>
    if (Test-Path -Path "C:\Temp\Transcript")
    {
        $OldTranscripts = (Get-ChildItem -Path "C:\Temp\Transcript" -Filter '*.txt' | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) })
        if ($OldTranscripts.Count -gt 0) {
            Write-Warning 'Removing Transcripts older than 30 days'
            $OldTranscripts | Remove-Item -Force -Verbose
        }
    }
    else 
    {
        Write-Warning "No Transcripts directory to clean"
    }
}

function Update-Profile {
    <#
.SYNOPSIS
Sources the Profile script
.DESCRIPTION
Sources the profile script so the user doesnt have to close and reopen powershell to
have changes take effect.

.EXAMPLE
Update-Profile
#>

    . $profile.CurrentUserAllHosts
}

function Edit-Profile {
    <#
.SYNOPSIS
Opens the profile.ps1 in the default editor

.DESCRIPTION
Opens the profile.ps1 for CurrentUserAllHosts in VSCode

.EXAMPLE
Edit-Profile
#>
    Set-Location -Path $ProfileDirectory
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $ProfileDirectory
    }
}

function Test-AdminPrivilege {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '', Scope = 'Function')]
    param()

    if ($IsWindows) {
        return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    else {
        return (id -u) -eq 0
    }
}

if ((Test-Path -Path $AdjectiveFile) -and ((Test-Path -Path $NounFile))) {
    function New-ProjectName {
        <#
.SYNOPSIS
Generates a project name from a random adjective and a random nown

.DESCRIPTION
Randomly grabs one noun and one adjective from a list of nouns and adjectives 
in the Data folder,  then string formats them together to create a project name

.EXAMPLE
New-ProjectName
#>
        $adjectives = Get-Content $AdjectiveFile
        $noun = Get-Content $NounFile
        $randomAdj = Get-Random -Minimum 0 -Maximum $adjectives.Length
        $randomNoun = Get-Random -Minimum 0 -Maximum $noun.Length
        '{0}{1}' -f (Get-Culture).TextInfo.ToTitleCase($adjectives[$randomAdj]), (Get-Culture).TextInfo.ToTitleCase($noun[$randomNoun]) | Write-Output
    }

    if ($GitHubCLIExists) {
        function New-Project {
            Param(
                [Parameter(Mandatory = $false)][string]$ProjectName,
                [switch]$PrivateRepo
            )

            if (-not $ProjectName) {
                $ProjectName = New-ProjectName
                Write-Warning "Project name was not specified, setting to $ProjectName"
            }

            Set-Location -Path $env:GIT_PROJECT_ROOT_PATH

            if ($PrivateRepo) {
                gh repo create $ProjectName --private --confirm
            }
            else {
                gh repo create $ProjectName --public --confirm
            }

            Set-Location -Path "$($env:GIT_PROJECT_ROOT_PATH)\$ProjectName"
        }
    }
}
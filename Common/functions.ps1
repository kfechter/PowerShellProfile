$ProfileDataPath = [IO.Path]::Combine($ProfileDirectory, 'Data')
$AdjectiveFile = [IO.Path]::Combine($ProfileDataPath, 'Adjectives.txt')
$NounFile = [IO.Path]::Combine($ProfileDataPath, 'Nouns.txt')

<#
    Helper function to abstract out paging and extraction of 'items'
        API docs:       https://api.stackexchange.com/docs
        Paging details: https://api.stackexchange.com/docs/paging

    Note: Explicitly removed functionality to limit pagesize on final call based on MaxResults.
          If the pagesize is changed, it breaks paging / sorting
#>

function Get-SEData {
    <#
    .SYNOPSIS
    Helper function for using the StackExchange API (DO NOT CALL DIRECTLY)
#>
    [cmdletbinding()]
    param (
        $IRMParams,
        [int]$Pagesize = 30,
        [int]$Page = 1,
        [int]$MaxResults
    )

    #Keep track of how many items we pull...
    [int]$ResultsSoFar = 0

    do {
        # If user specified page, and not first loop, don't touch it. Otherwise, set it!
        if (-not ($ResultsSoFar -eq 0 -and $IRMParams.ContainsKey('page'))) {
            $IRMParams.Body.page = $Page
        }

        #init pagesize
        if ($IRMParams.Body.ContainsKey('PageSize')) {
            #Normal. Pagesize was specified. Pull it out for simplicity.
            $Pagesize = $IRMParams.Body.pagesize
        }
        else {
            #Something odd happened. Pagesize should have been specified.
            $IRMParams.Body.pagesize = $Pagesize
        }

        # First run and maxresults is lower than pagesize? Overruled!
        if ($ResultsSoFar -eq 0 -and $Pagesize -gt $MaxResults) {
            $IRMParams.Body.pagesize = $Pagesize = $MaxResults
        }

        #Collect the results
        Try {
            write-debug "Final $($IRMParams | Out-string) Body $($IRMParams.Body | Out-String)"

            #We might want to track the HTTP status code to verify success for non-gets...
            $TempResult = Invoke-RestMethod @IRMParams

            Write-Debug "Raw:`n$($TempResult | Out-String)"
        }
        Catch {
            Throw $_
        }

        if ($TempResult.PSObject.Properties.Name -contains 'items') {
            $TempResult.items
        }
        else {
            # what is going on!
            $TempResult
        }

        #How many results have we seen?
        [int]$ResultsSoFar += $Pagesize
        $Page++

        Write-Debug "
            ResultsSoFar = $ResultsSoFar
            PageSize = $PageSize
            Page++ = $Page
            MaxResults = $MaxResults
            (ResultsSoFar + PageSize) -gt MaxResults $(($ResultsSoFar + $PageSize) -gt $MaxResults)
            ResultsSoFar -ne MaxResults $($ResultsSoFar -ne $MaxResults)"

        #Loop readout
        Write-Debug "TempResult.has_more: $($TempResult.has_more)`n Not TempResult.items = $(-not $TempResult.items)`n ResultSoFar -gt MaxResults: $ResultsSoFar -gt $MaxResults"
    }
    until (
        $TempResult.has_more -ne $true -or
        -not $TempResult.items -or
        $ResultsSoFar -ge $MaxResults
    )
}

function Join-Part {
    <#
    .SYNOPSIS
        Join strings with a specified separator.

    .DESCRIPTION
        Join strings with a specified separator.

        This strips out null values and any duplicate separator characters.

        See examples for clarification.

    .PARAMETER Separator
        Separator to join with

    .PARAMETER Parts
        Strings to join

    .EXAMPLE
        Join-Parts -Separator "/" this //should $Null /work/ /well

        # Output: this/should/work/well

    .EXAMPLE
        Join-Parts -Parts http://this.com, should, /work/, /wel

        # Output: http://this.com/should/work/wel

    .EXAMPLE
        Join-Parts -Separator "?" this ?should work ???well

        # Output: this?should?work?well

    .EXAMPLE

        $CouldBeOneOrMore = @( "JustOne" )
        Join-Parts -Separator ? -Parts CouldBeOneOrMore

        # Output JustOne

        # If you have an arbitrary count of parts coming in,
        # Unnecessary separators will not be added

    .NOTES
        Credit to Rob C. and Michael S. from this post:
        http://stackoverflow.com/questions/9593535/best-way-to-join-parts-with-a-separator-in-powershell

    #>
    [cmdletbinding()]
    param
    (
        [string]$Separator = '/',

        [parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Parts = $null

    )

    ( $Parts |
        Where-Object { $_ } |
        ForEach-Object { ( [string]$_ ).trim($Separator) } |
        Where-Object { $_ }
    ) -join $Separator
}

function Add-ObjectDetail {
    <#
    .SYNOPSIS
        Decorate an object with
            - A TypeName
            - New properties
            - Default parameters

    .DESCRIPTION
        Helper function to decorate an object with
            - A TypeName
            - New properties
            - Default parameters

    .PARAMETER InputObject
        Object to decorate. Accepts pipeline input.

    .PARAMETER TypeName
        Typename to insert.

        This will show up when you use Get-Member against the resulting object.

    .PARAMETER PropertyToAdd
        Add these noteproperties.

        Format is a hashtable with Key (Property Name) = Value (Property Value).

        Example to add a One and Date property:

            -PropertyToAdd @{
                One = 1
                Date = (Get-Date)
            }

    .PARAMETER DefaultProperties
        Change the default properties that show up

    .PARAMETER Passthru
        Whether to pass the resulting object on. Defaults to true

    .EXAMPLE
        #
        # Create an object to work with
        $Object = [PSCustomObject]@{
            First = 'Cookie'
            Last = 'Monster'
            Account = 'CMonster'
        }

        #Add a type name and a random property
        Add-ObjectDetail -InputObject $Object -TypeName 'ApplicationX.Account' -PropertyToAdd @{ AnotherProperty = 5 }

            # First  Last    Account  AnotherProperty
            # -----  ----    -------  ---------------
            # Cookie Monster CMonster               5

        #Verify that get-member shows us the right type
        $Object | Get-Member

            # TypeName: ApplicationX.Account ...

    .EXAMPLE
        #
        # Create an object to work with
        $Object = [PSCustomObject]@{
            First = 'Cookie'
            Last = 'Monster'
            Account = 'CMonster'
        }

        #Add a random property, set a default property set so we only see two props by default
        Add-ObjectDetail -InputObject $Object -PropertyToAdd @{ AnotherProperty = 5 } -DefaultProperties Account, AnotherProperty

            # Account  AnotherProperty
            # -------  ---------------
            # CMonster               5

        #Verify that the other properties are around
        $Object | Select -Property *

            # First  Last    Account  AnotherProperty
            # -----  ----    -------  ---------------
            # Cookie Monster CMonster               5

    .NOTES
        This breaks the 'do one thing' rule from certain perspectives...
        The goal is to decorate an object all in one shot

        This abstraction simplifies decorating an object, with a slight trade-off in performance. For example:

        10,000 objects, add a property and typename:
            Add-ObjectDetail:                        ~4.6 seconds
            Add-Member + PSObject.TypeNames.Insert:  ~3 seconds

        Initial code borrowed from Shay Levy:
        http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/

    .LINK
        http://ramblingcookiemonster.github.io/Decorating-Objects/

    .FUNCTIONALITY
        PowerShell Language
    #>
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true )]
        [ValidateNotNullOrEmpty()]
        [psobject[]]$InputObject,

        [Parameter( Mandatory = $false,
            Position = 1)]
        [string]$TypeName,

        [Parameter( Mandatory = $false,
            Position = 2)]
        [System.Collections.Hashtable]$PropertyToAdd,

        [Parameter( Mandatory = $false,
            Position = 3)]
        [ValidateNotNullOrEmpty()]
        [Alias('dp')]
        [System.String[]]$DefaultProperties,

        [boolean]$Passthru = $True
    )

    Begin {
        if ($PSBoundParameters.ContainsKey('DefaultProperties')) {
            # define a subset of properties
            $ddps = New-Object System.Management.Automation.PSPropertySet DefaultDisplayPropertySet, $DefaultProperties
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$ddps
        }
    }
    Process {
        foreach ($Object in $InputObject) {
            switch ($PSBoundParameters.Keys) {
                'PropertyToAdd' {
                    foreach ($Key in $PropertyToAdd.Keys) {
                        #Add some noteproperties. Slightly faster than Add-Member.
                        $Object.PSObject.Properties.Add( ( New-Object System.Management.Automation.PSNoteProperty($Key, $PropertyToAdd[$Key]) ) )
                    }
                }
                'TypeName' {
                    #Add specified type
                    [void]$Object.PSObject.TypeNames.Insert(0, $TypeName)
                }
                'DefaultProperties' {
                    # Attach default display property set
                    Add-Member -InputObject $Object -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers
                }
            }
            if ($Passthru) {
                $Object
            }
        }
    }
}

Function ConvertTo-UnixDate {
    <#
    .SYNOPSIS
        Convert from DateTime to Unix date

    .DESCRIPTION
        Convert from DateTime to Unix date

    .PARAMETER Date
        Date to convert

    .PARAMETER Utc
        Default behavior is to convert Date to universal time.  Set this to false to skip this step.

    .EXAMPLE
        ConvertTo-UnixDate -Date (Get-date)

    .FUNCTIONALITY
        General Command
    #>
    Param(
        [datetime]$Date = (Get-Date),
        [bool]$Utc = $true
    )

    #Borrowed from the internet, presumably.

    if ($utc) {
        $Date = $Date.ToUniversalTime()
    }

    $unixEpochStart = new-object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
    [int]($Date - $unixEpochStart).TotalSeconds
}

Function ConvertFrom-UnixDate {
    <#
    .SYNOPSIS
        Convert from Unix time to DateTime

    .DESCRIPTION
        Convert from Unix time to DateTime

    .PARAMETER Date
        Date to convert, in Unix / Epoch format

    .PARAMETER Utc
        Default behavior is to convert Date to universal time.

        Set this to false to return local time.

    .EXAMPLE
        ConvertFrom-UnixDate -Date 1441471257

    .FUNCTIONALITY
        General Command
    #>
    Param(
        [int]$Date,
        [bool]$Utc = $true
    )

    # Adapted from http://stackoverflow.com/questions/10781697/convert-unix-time-with-powershell
    $unixEpochStart = new-object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
    $Output = $unixEpochStart.AddSeconds($Date)

    if (-not $utc) {
        $Output = $Output.ToLocalTime()
    }

    $Output
}

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
        return Test-Path '/var/run/reboot-required'
    }
    elseif ($IsWindows) {
        if (Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -EA Ignore) { return $true }
        if (Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -EA Ignore) { return $true }
        if (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -EA Ignore) { return $true }
        try {
            $util = [wmiclass]'\\.\root\ccm\clientsdk:CCM_ClientUtilities'
            $status = $util.DetermineIfRebootPending()
            if (($null -ne $status) -and $status.RebootPending) {
                return $true
            }
        }
        catch {}
        return $false
    }
    else {
        Write-Warning 'This operating system is not supported. Cannot determine pending reboot status.'
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

function Invoke-Magic8Ball {
    <#
.SYNOPSIS
Provides a silly answer to a question.

.DESCRIPTION
Returns 1 of 20 possible answers to a question.

.EXAMPLE
PS> Invoke-Magic8Ball -Question 'Will I win the lottery'
It is Certain.
#>
    Param(
        [Parameter(Mandatory = $true)][string]$Question
    )

    $null = $Question # Eat the question

    $Answers = @(
        'It is certain.',
        'It is decidedly so.',
        'Without a doubt.',
        'Yes definitely.',
        'You may rely on it.',
        'As I see it, yes.',
        'Most likely.',
        'Outlook good.',
        'Yes.',
        'Signs point to yes.',
        'Reply hazy, try again.',
        'Ask again later.',
        'Better not tell you now.',
        'Cannot predict now.',
        'Concentrate and ask again.',
        'Don''t count on it.',
        'My reply is no.',
        'My sources say no.',
        'Outlook not so good.',
        'Very doubtful.')

    $Response = (Get-Random -Minimum 0 -Maximum 19)
    $Color = if ($Response -le 9) { 'Green' } elseif (($Response -gt 9) -and ($Response -le 14)) { 'Yellow' } elseif (($Response -gt 14) -and ($Response -le 19)) { 'Red' }

    $Answers[$Response] | Write-Output -ForegroundColor $Color
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

    $url = 'https://wttr.in/{0}?{1}FT' -f $City, $DetailLevel
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
        Write-Output 'Transcription is now Disabled'
        Stop-Transcript
    }
    else {
        Write-Output 'Transcription is now Enabled'
        Start-Transcript -Path $TranscriptPath
    }

    $TranscriptSettingsRootPath = [System.IO.Path]::GetDirectoryName($profile.CurrentUserAllHosts)
    (-Not $Transcript) | Export-Clixml -Path "$TranscriptSettingsRootPath\Settings\TranscriptEnabled.clixml"
}

function Clear-Transcript {
    <#
.SYNOPSIS
Clears transcripts older than 30 days.

.DESCRIPTION
Removes all transcript text files older than 30 days from the profile transcript directory.

.EXAMPLE
PS> Clear-Transcripts
WARNING: Removing Transcripts older than 30 days
VERBOSE: Performing the operation "Remove File" on target $TranscriptDirectory".
#>
    if (Test-Path -Path $TranscriptDirectory) {
        $OldTranscripts = (Get-ChildItem -Path $TranscriptDirectory -Filter '*.txt' | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) })
        if ($OldTranscripts.Count -gt 0) {
            Write-Warning 'Removing Transcripts older than 30 days'
            $OldTranscripts | Remove-Item -Force -Verbose
        }
    }
    else {
        Write-Warning 'No Transcripts directory to clean'
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
        return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
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
        <#
.SYNOPSIS
Generates a project and configures it on GitHub.

.DESCRIPTION
If project name is specified, then repo is created with that name, otherwise it uses the New-ProjectName function.

.EXAMPLE
New-Project

.EXAMPLE
New-Project -ProjectName 'ProjectName'

.EXAMPLE
New-Project -$PrivateRepo:$true
#>
        function New-Project {
            Param(
                [Parameter(Mandatory = $false)][string]$ProjectName,
                [bool]$PrivateRepo
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
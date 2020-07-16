function Test-PendingReboot {
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
            if(($null -ne $status) -and $status.RebootPending){
                return $true
            }
        } catch{}
        return $false
	} 
	else {
	    Write-Warning "This operating system is not supported. Cannot determine pending reboot status."
		return $False
	}
}

function Rename-Branches {
    $CurrentPath = Get-Location
    if(-Not (Test-Path -Path "$CurrentPath\.git")) {
        Write-Warning 'This function must be run in a git repository'
        return
    }

    # check for uncommitted changes, Check for a master branch, branch "main" from master and delete master
}

function Clear-DeletedBranches {
    $CurrentPath = Get-Location
    if(-Not (Test-Path -Path "$CurrentPath\.git")) {
        Write-Warning 'This function must be run in a git repository'
        return
    }

    git remote prune origin
    $PrunedBranches = (git branch -vv) | Where-Object { $_ -ilike '*: gone]*'}
    $PrunedBranches | ForEach-Object {
        $BranchName = (($_.Split('['))[1].Split(':'))[0].Replace('origin/','')
        git branch -d $BranchName
    }
}

function New-Repo
{
    <#
.SYNOPSIS
Creates a new git repository with default branch main

.DESCRIPTION

Creates a new git repository and changes default branch to main. If no 
path specified, assumes current directory

.PARAMETER Path
[Optional] Specifies the path to the repository.

.PARAMETER RemoteOrigin
[Optional] Specifies the remote repository to set as 'origin'

.EXAMPLE

PS> New-Repository

.EXAMPLE

PS> New-Repository -Path C:\Projects\Repository

.EXAMPLE

PS> New-Repository -Path C:\Projects\Repository -RemoteOrigin git@github.com:kfechter/PowerShellProfile.git

.EXAMPLE

PS> New-Repository -Path C:\Projects\ExistingNonEmptyFolder -Force

#>
    Param(
        [Parameter(Mandatory=$false)][string]$Path,
        [Parameter(Mandatory=$false)][string]$RemoteOrigin,
        [switch]$Force
    )

    if($Path) {
        $DirectoryPath = $Path
    }
    else {
        $DirectoryPath = Get-Location
    }

    if(-Not (Test-Path -Path $DirectoryPath)) {
        New-Item -ItemType Directory -Path $DirectoryPath
    }

    $IsGitRepo = (Test-Path -Path "$DirectoryPath\.git")

    if($IsGitRepo) {
        Write-Warning 'Path is already a git repository.'
        return
    }

    $DirectoryContents = Get-ChildItem -Path $DirectoryPath -Force
    if(($DirectoryContents.Count -gt 0) -and -Not $Force) {
        Write-Warning 'Path is not empty, specify -Force to ignore empty directories'
        return
    }

    Push-Location $DirectoryPath
    git init
    git checkout -b main
    git branch -d master

    if($RemoteOrigin) {
        git remote add origin $RemoteOrigin
    }

    Pop-Location
}

function Push-Repo {
    Param(
        [Parameter(Mandatory=$true)][string]$CommitMessage,
        [Parameter(Mandatory=$false)][string]$GitRemoteURL
    )

    # Check to make sure we are in a git controlled folder
    $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter ".git"
    if($GitFolder.Count -eq 0) {
        Write-Warning "Not a git Repository"
        return
    }


    # Check if Repo has remote
    $Remotes = (git remote)
    $MissingRemotes = $Remotes.Count -eq 0
    if ($MissingRemotes -and -Not $GitRemoteURL) {
        Write-Warning "Remote URL Required as repo does not have any origin"
        return
    }
    elseif($MissingRemotes)
    {
        git remote add origin $GitRemoteURL
    }

    # Check if the current Branch has an upstream
    $CurrentBranch = ((git branch) | Where-Object { $_ -like '*`**' }).Replace('*', '').Trim()
    $BranchStatus = (git status -sb)

    if($BranchStatus -like "*origin/$CurrentBranch") {
        Write-Host "Branch Has Remote"
        git add -A
        git commit -m $CommitMessage
        git push
    }
    else {
        Write-Host "Branch Does Not Have Remote Tracking"
        git add -A
        git commit -m $CommitMessage
        if($MissingRemotes) {
            git push --set-upstream origin $CurrentBranch --allow-unrelated-histories
        }
        else {
            git push --set-upstream origin $CurrentBranch
        }
    }
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
    
        [CmdletBinding(SupportsShouldProcess=$True)]
        param()
    
        Write-Verbose 'Running function TEST-TRANSCRIBING....'
        Write-Verbose 'Set Boolean value to false by default'
        $IsTranscribing = $false
    
        Write-Information 'Testing to see if powershell is transcribing.  If so, we will stop and re-start transcription'
    
        Write-Verbose 'Now we test to see if transcribing is in progress' 
        $stopTest = try {Stop-transcript -ErrorAction stop} catch {}                                                      
     
        if (!$stopTest) {write-Verbose 'No Transcription was started, we do nothing.'}                                     
    
        if ($stopTest -and $stoptest.Contains('not been started')) {write-Verbose 'No Transcription was started, we do nothing.'}                                     
     
        if ($stopTest -and $stoptest.Contains('output file'))
        {
            Write-Verbose 'A running transcript was found, resuming...'
            Start-Transcript -path $stoptest.Split(' ')[$stoptest.Split(' ').count-1] -append  | out-null
            Write-Information 'Stopped and restarted the transcription as part of the TEST-TRANSCRIBING function'                             
            $IsTranscribing = $True
        }                              
    
        Write-Verbose "Returning the value of $IsTranscribing to the calling script"
        Return $IsTranscribing
    }
    
    function Switch-Transcript {
        $Transcript = Test-Transcription
        if ($Transcript) {
            Stop-Transcript
        } else {
            Start-Transcript -Path $global:TranscriptFullPath
        }
    }
    
    function Clear-Transcripts {
        $OldTranscripts = (Get-ChildItem -Path $global:TranscriptDirectory -Filter '*.txt' | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-30)})
        if ($OldTranscripts.Count -gt 0) {
            Write-Warning 'Removing Transcripts older than 30 days'
            $OldTranscripts | Remove-Item -Force
        }
    }
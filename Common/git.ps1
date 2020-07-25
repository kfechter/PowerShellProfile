function New-Repo {
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
        [Parameter(Mandatory = $false)][string]$Path,
        [Parameter(Mandatory = $false)][string]$RemoteOrigin,
        [switch]$Force
    )

    if ($Path) {
        $DirectoryPath = $Path
    }
    else {
        $DirectoryPath = Get-Location
    }

    if (-Not (Test-Path -Path $DirectoryPath)) {
        New-Item -ItemType Directory -Path $DirectoryPath
    }

    $IsGitRepo = (Test-Path -Path "$DirectoryPath\.git")

    if ($IsGitRepo) {
        Write-Warning 'Path is already a git repository.'
        return
    }

    $DirectoryContents = Get-ChildItem -Path $DirectoryPath -Force
    if (($DirectoryContents.Count -gt 0) -and -Not $Force) {
        Write-Warning 'Path is not empty, specify -Force to ignore empty directories'
        return
    }

    Push-Location $DirectoryPath
    git init
    git checkout -b main
    git branch -d master

    if ($RemoteOrigin) {
        git remote add origin $RemoteOrigin
    }

    Pop-Location
}

function Push-Repo {
    <#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER CommitMessage
Parameter description

.PARAMETER GitRemoteURL
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>


    Param(
        [Parameter(Mandatory = $true)][string]$CommitMessage,
        [Parameter(Mandatory = $false)][string]$GitRemoteURL
    )

    # Check to make sure we are in a git controlled folder
    $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter ".git"
    if ($GitFolder.Count -eq 0) {
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
    elseif ($MissingRemotes) {
        git remote add origin $GitRemoteURL
    }

    # Check if the current Branch has an upstream
    $CurrentBranch = ((git branch) | Where-Object { $_ -like '*`**' }).Replace('*', '').Trim()
    $BranchStatus = (git status -sb)

    if ($BranchStatus -like "*origin/$CurrentBranch") {
        Write-Warning "Branch Has Remote Tracking" -InformationAction Continue
        git add -A
        git commit -m $CommitMessage
        git push
    }
    else {
        Write-Warning "Branch Does Not Have Remote Tracking"
        git add -A
        git commit -m $CommitMessage
        if ($MissingRemotes) {
            git push --set-upstream origin $CurrentBranch --allow-unrelated-histories
        }
        else {
            git push --set-upstream origin $CurrentBranch
        }
    }
}

function Clear-DeletedBranches {
    <#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>

    $CurrentPath = Get-Location
    if (-Not (Test-Path -Path "$CurrentPath\.git")) {
        Write-Warning 'This function must be run in a git repository'
        return
    }

    git remote prune origin
    $PrunedBranches = (git branch -vv) | Where-Object { $_ -ilike '*: gone]*' }
    $PrunedBranches | ForEach-Object {
        $BranchName = (($_.Split('['))[1].Split(':'))[0].Replace('origin/', '')
        git branch -d $BranchName
    }
}

function Rename-Branches {
    <#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>

    $CurrentPath = Get-Location
    if (-Not (Test-Path -Path "$CurrentPath\.git")) {
        Write-Warning 'This function must be run in a git repository'
        return
    }

    # check for uncommitted changes, Check for a master branch, branch "main" from master and delete master
}
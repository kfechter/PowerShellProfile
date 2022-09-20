# Important Parameters up here
$GitHubCLIExists = Get-Command 'gh.exe' -ErrorAction SilentlyContinue
$NonRepoWarning = 'Current Directory is not a Git repository.'
$BranchNameFilter = @('master', 'slave')

function Test-IsGitRepo {
    <#
.SYNOPSIS
Checks if the current directory is a git repository

.DESCRIPTION
Checks for the existence of a .git folder, signifying that the current directory is
set up to be a git repository. Helper function for the rest of the functions in this script

.EXAMPLE
PS> Test-GitRepo
False

#>

    $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter '.git'
    return ($GitFolder.Count -ne 0)
}

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

PS> New-Repo

.EXAMPLE

PS> New-Repo -Path C:\Projects\Repository

.EXAMPLE

PS> New-Repo -Path C:\Projects\Repository -RemoteOrigin git@github.com:kfechter/PowerShellProfile.git

.EXAMPLE

PS> New-Repo -Path C:\Projects\ExistingNonEmptyFolder -Force

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
Pushes local repository changes to a remote repository

.DESCRIPTION
Creates a commit with the specified message and pushes the commit to the remote repository.
Can add remote origin if none exists, and will automatically add remote tracking for new local branches.

.PARAMETER CommitMessage
[Required] The commit message used for the commit of all the changes.

.PARAMETER GitRemoteURL
[Optional] If no remote origin is set, this will need to be passed. the url of the remote repository to commit to.

.PARAMETER GeneratePullRequest
[Switch] [ParameterSet = GeneratePullRequestParamSet]
Optional Switch parameter that tells the push-repo cmdlet to open a pull request from this branch to
the default branch or to a named branch. If specified, there are additional required parameters that also
need to be specified. This parameter is dynamic and will not load if the github cli is not installed.

.PARAMETER RequestTitle
[Required for ParameterSet GeneratePullRequestParamSet]
If GeneratePullRequest is specified, this is required. The Title for the pull request.
This parameter is dynamic and will not load if the github cli is not installed.

.PARAMETER RequestBody
[Required for ParameterSet GeneratePullRequestParamSet]
If GeneratePullRequest is specified, this is required. The body text for the pull request.
This parameter is dynamic and will not load if the github cli is not installed.

.PARAMETER Labels
[Optional for ParameterSet GeneratePullRequestParamSet]
If specified, the labels to attach to the pull request. These must exist on the github repo,
and are case sensitive. This parameter is dynamic and will not load if the github cli is not installed.

.PARAMETER BaseBranch
[Optional for ParameterSet GeneratePullRequestParamSet]
If specified, the base branch to merge the pull request into. The base branch must exist on the remote repo.
This parameter is dynamic and will not load if the github cli is not installed.


.EXAMPLE
Push-Repo -CommitMessage "Adding functionality to script"

.EXAMPLE
Push-Repo -CommitMessage "Adding functionality to script" -GitRemoteURL "git@github.com:kfechter/PowerShellProfile.git"

.EXAMPLE
Push-Repo -CommitMessage "Adding functionality to script" -GitRemoteURL "git@github.com:kfechter/PowerShellProfile.git" -GeneratePullRequest -RequestTitle "Merge feature into main" -RequestBody "This PR merges functionality from <branch> to main"

.EXAMPLE
Push-Repo -CommitMessage "Adding functionality to script" -GitRemoteURL "git@github.com:kfechter/PowerShellProfile.git" -GeneratePullRequest -RequestTitle "Merge feature into main" -RequestBody "This PR merges functionality from <branch> to main" -Labels "enhancement"

.EXAMPLE
Push-Repo -CommitMessage "Adding functionality to script" -GitRemoteURL "git@github.com:kfechter/PowerShellProfile.git" -GeneratePullRequest -RequestTitle "Merge feature into main" -RequestBody "This PR merges functionality from <branch> to main" -Labels "enhancement" -BaseBranch "<alternatebranch>"

.NOTES
Additional functionality of this cmdlet requires the Github CLI beta to be installed and configured.
see https://cli.github.com/ for the tool.
#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Positional parameters is fine here')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CommitMessage,
        [Parameter(Mandatory = $false)][string]$GitRemoteURL
    )

    DynamicParam {
        # Create a new parameter dictionary
        $runtimeParams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Add optional attributes to parameter
        $generatePullRequestAttributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $requiredParametersAttributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $optionalParametersAttributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        $generatePullRequestAttribute = New-Object System.Management.Automation.ParameterAttribute
        $generatePullRequestAttribute.Mandatory = $false
        $generatePullRequestAttribute.ParameterSetName = 'GeneratePullRequestParamSet'
        $generatePullRequestAttributes.Add($generatePullRequestAttribute)

        $requiredParametersAttribute = New-Object System.Management.Automation.ParameterAttribute
        $requiredParametersAttribute.ParameterSetName = 'GeneratePullRequestParamSet'
        $requiredParametersAttribute.Mandatory = $true
        $requiredParametersAttributes.Add($requiredParametersAttribute)

        $optionalParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $requiredParametersAttribute.ParameterSetName = 'GeneratePullRequestParamSet'
        $requiredParametersAttribute.Mandatory = $false
        $optionalParametersAttributes.Add($optionalParameterAttribute)

        if ($GitHubCLIExists) {
            # Create "GeneratePullRequest" Parameters
            $parameterGeneratePullRequest = New-Object System.Management.Automation.RuntimeDefinedParameter('GeneratePullRequest', [switch], $generatePullRequestAttributes)
            $parameterPullRequestTitle = New-Object System.Management.Automation.RuntimeDefinedParameter('RequestTitle', [string], $requiredParametersAttributes)
            $parameterPullRequestBody = New-Object System.Management.Automation.RuntimeDefinedParameter('RequestBody', [string], $requiredParametersAttributes)
            $parameterLabels = New-Object System.Management.Automation.RuntimeDefinedParameter('Labels', [string[]], $optionalParametersAttributes)
            $parameterBaseBranch = New-Object System.Management.Automation.RuntimeDefinedParameter('BaseBranch', [string], $optionalParametersAttributes)
            $runtimeParams.Add('GeneratePullRequest', $parameterGeneratePullRequest)
            $runtimeParams.Add('RequestTitle', $parameterPullRequestTitle)
            $runtimeParams.Add('RequestBody', $parameterPullRequestBody)
            $runtimeParams.Add('Labels', $parameterLabels)
            $runtimeParams.Add('BaseBranch', $parameterBaseBranch)
        }

        return $runtimeParams
    }

    Begin {
        # Create variables from dynamic parameters
        if ($GitHubCLIExists) {
            $GeneratePullRequest = $PSBoundParameters['GeneratePullRequest']
            $BaseBranch = $PSBoundParameters['BaseBranch']
            $RequestTitle = $PSBoundParameters['RequestTitle']
            $RequestBody = $PSBoundParameters['RequestBody']
            $Labels = $PSBoundParameters['Labels']
        }
    }

    Process {
        # Check to make sure we are in a git controlled folder
        $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter '.git'
        if ($GitFolder.Count -eq 0) {
            Write-Warning 'Not a git Repository'
            return
        }

        # Check if repo has remote
        $Remotes = (git remote)
        $MissingRemotes = $Remotes.Count -eq 0
        if ($MissingRemotes -and -Not $GitRemoteURL) {
            Write-Warning 'Remote URL Required as repo does not have any origin'
            return
        }
        elseif ($MissingRemotes) {
            git remote add origin $GitRemoteURL
        }

        # Check if the current branch is tracked upstream
        $CurrentBranch = ((git branch) | Where-Object { $_ -like '*`**' }).Replace('*', '').Trim()
        # Check if the current Branch has an upstream
        $BranchStatus = (git status -sb)

        if ($BranchStatus -like "*origin/$CurrentBranch") {
            Write-Warning 'Branch Has Remote Tracking' -InformationAction Continue
            git pull
            git add -A
            git commit -m $CommitMessage
            git push
        }
        else {
            Write-Warning 'Branch Does Not Have Remote Tracking'
            git add -A
            git commit -m $CommitMessage
            if ($MissingRemotes) {
                git push --set-upstream origin $CurrentBranch --allow-unrelated-histories
            }
            else {
                git push --set-upstream origin $CurrentBranch
            }
        }

        if ($GeneratePullRequest) {
            $PullRequestParameters = @{
                'RequestTitle' = $RequestTitle
                'RequestBody' = $RequestBody
            }

            if ($Labels) {
                $PullRequestParameters += @{
                    'Labels' = $Labels
                }
            }

            if ($BaseBranch) {
                $PullRequestParameters += @{
                    'BaseBranch' = $BaseBranch
                }
            }

            New-PullRequest @PullRequestParameters
        }
    }
}
function Clear-DeletedBranch {
    <#
.SYNOPSIS
Clears branches that have been deleted on the remote, but are not deleted from local.

.DESCRIPTION
Gets all branches and parses them for [gone] which states that the branch no longer exists on the remote.
Fetches the repo origin, then prunes and deletes branches that no longer have a remote. (are '[gone]').

.EXAMPLE
PS> Clear-Branches
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

function Rename-Branch {
    <#
.SYNOPSIS
Renames the "master" branch of a repository to "main"

.DESCRIPTION
This function branches "master" to "main", and then deletes the branch named "master"
Requires repo to exist on a remote currently

.EXAMPLE
PS> Rename-Branches

.NOTES
Take caution running this, as there may be unintended side-effects.
see here for reasoning about branch rename https://www.hanselman.com/blog/EasilyRenameYourGitDefaultBranchFromMasterToMain.aspx
#>

    if (-Not (Test-IsGitRepo)) {
        Write-Warning 'This function must be run in a git repository'
        return
    }

    $CurrentBranch = git branch --show-current
    if ($CurrentBranch -ne 'master') {
        Write-Warning 'You must be on the master branch for the rename to work'
        return
    }

    $GitChanges = git status --porcelain

    if ($GitChanges.Count -gt 0) {
        Write-Warning 'Please stash or commit all changes or they will be lost'
        return
    }

    $GitCommits = git cherry -v
    if ($GitCommits.Count -gt 0) {
        Write-Warning 'Please push all commits to remote before running or they will be lost.'
        return
    }

    git checkout -b main
    git branch -d master
    Push-Repo -CommitMessage "Renaming 'Master' branch to 'main'"
}

if ($GitHubCLIExists) {
    function New-PullRequest {
        <#
    .SYNOPSIS
    Creates a pull request from the current branch to the default/specified branch

    .DESCRIPTION
    Using the github CLI, creates a pull request for the current repo to the default branch if none is
    specified, or to a named branch if specified. Can also attach labels.

    .PARAMETER RequestTitle
    [Mandatory] Specifies the title for the Pull Request

    .PARAMETER RequestBody
    [Mandatory] Specifies the body text for the pull request

    .PARAMETER Labels
    [Optional] Specifies one or more labels in string array format for attaching to PR.
    These lablels must already exist in GitHub

    .PARAMETER BaseBranch
    [Optional] Specifies a branch name other than the default branch to base the merge request on.

    .EXAMPLE
    PS> New-PullRequest -RequestTitle "Merge Branch <branch> into <base>" -RequestBody "Merging a thing into a branch"

    .EXAMPLE
    PS> New-PullRequest -RequestTitle "Merge Branch <branch> into <base>" -RequestBody "Merging a thing into a branch" -Labels 'enhancement'

    .EXAMPLE
    PS> New-PullRequest -RequestTitle "Merge Branch <branch> into <base>" -RequestBody "Merging a thing into a branch" -Labels 'enhancement' -BaseBranch "alternatebranchname"

    .NOTES
    Requires the github CLI, if not installed, profile will not even load these functions. https://cli.github.com/
    #>

        param(
            [Parameter(Mandatory = $true)][string]$RequestTitle,
            [Parameter(Mandatory = $true)][string]$RequestBody,
            [Parameter(Mandatory = $false)][string[]]$Labels,
            [Parameter(Mandatory = $false)][string]$BaseBranch
        )

        # Check to make sure we are in a git controlled folder
        $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter '.git'
        if ($GitFolder.Count -eq 0) {
            Write-Warning 'Not a git Repository'
            return
        }

        # Check to make sure we are not on the 'main' branch.
        $CurrentBranch = ((git branch) | Where-Object { $_ -like '*`**' }).Replace('*', '').Trim()
        if ((($CurrentBranch -eq 'main') -or ($CurrentBranch -eq 'master')) -and -Not $BaseBranch) {
            Write-Warning "Branch is currently on $CurrentBranch. This is the default branch."
            Write-Warning 'Run this command to create a pull request from a non default branch or specify a base branch'
            return
        }

        $LabelParameter = ''

        if ($Labels) {
            $LabelParameter = $Labels -join ','
        }

        if ($Labels -and $BaseBranch) {
            & gh pr create --title "$RequestTitle" --body "$RequestBody" --label "$LabelParameter" --base "$BaseBranch"
        }
        elseif ($Labels) {
            & gh pr create --title "$RequestTitle" --body "$RequestBody" --label "$LabelParameter"
        }
        elseif ($BaseBranch) {
            & gh pr create --title "$RequestTitle" --body "$RequestBody" --base "$BaseBranch"
        }
        else {
            & gh pr create --title "$RequestTitle" --body "$RequestBody"
        }
    }

    function Merge-PullRequest {
        <#
    .SYNOPSIS
    Merges a pull request.

    .DESCRIPTION
    Merges the specified pull request or lists all available PRs for a repo and prompts the user to enter a number.

    .PARAMETER PullRequestNumber
    [Optional] If specified, sets the PR being merged. Function will list all PRs and prompt if not specified

    .EXAMPLE
    PS> Merge-PullRequest

    .EXAMPLE
    PS> Merge-PullRequest -PullRequestNumber 7

    .NOTES
    Requires the github CLI, if not installed, profile will not even load these functions. https://cli.github.com/
    #>

        param(
            [Parameter(Mandatory = $false)][int]$PullRequestNumber
        )

        # Check to make sure we are in a git controlled folder
        $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter '.git'
        if ($GitFolder.Count -eq 0) {
            Write-Warning 'Not a git Repository'
            return
        }

        if (-Not $PullRequestNumber) {
            Write-Warning 'No Pull Request Number Selected, Please Specify one from the following list'
            gh pr list
            $PullRequestNumber = Read-Host -Prompt 'Enter the number of the Pull request you want'
        }

        gh pr merge $PullRequestNumber --merge --delete-branch
        git pull
    }
}

function New-Branch {
    <#
.SYNOPSIS
Creates a new local branch of a git repo and optionally pushes it to the remote.

.DESCRIPTION
This function will create a new local branch 'git checkout -b <branch name>' and then optionally push
it to the remote. Has a filter that can be added to to prevent certain branch names from being used.

.PARAMETER BranchName
[Required] The name of the new branch to create.

.PARAMETER PushRepo
[Optional] An optional switch to tell the function to push the new branch to the remote repository.
Will fail if Remote is not set.

.EXAMPLE
New-Branch -BranchName 'TestBranch'

.EXAMPLE
New-Branch -BranchName 'TestBranch' -PushRepo

#>

    param(
        [Parameter(Mandatory = $true)][string]$BranchName,
        [Parameter(Mandatory = $false)][switch]$PushRepo
    )

    if (-Not (Test-IsGitRepo)) {
        Write-Warning $NonRepoWarning
    }

    if ($BranchName -in $BranchNameFilter) {
        Write-Warning 'Consider using branch names that are more inclusive'
        return
    }

    git checkout -b $BranchName

    if ($PushRepo) {
        Push-Repo -CommitMessage 'Pushing new branch to remote repository.'
    }
}
# Important Parameters up here
$GitHubCLIExists = Get-Command 'gh.exe' -ErrorAction SilentlyContinue

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
        $generatePullRequestAttribute.ParameterSetName = "GeneratePullRequestParamSet"
        $generatePullRequestAttributes.Add($generatePullRequestAttribute)

        $requiredParametersAttribute = New-Object System.Management.Automation.ParameterAttribute
        $requiredParametersAttribute.ParameterSetName = "GeneratePullRequestParamSet"
        $requiredParametersAttribute.Mandatory = $true
        $requiredParametersAttributes.Add($requiredParametersAttribute)

        $optionalParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $requiredParametersAttribute.ParameterSetName = "GeneratePullRequestParamSet"
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
        $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter ".git"
        if ($GitFolder.Count -eq 0) {
            Write-Warning "Not a git Repository"
            return
        }

        # Check if repo has remote
        $Remotes = (git remote)
        $MissingRemotes = $Remotes.Count -eq 0
        if ($MissingRemotes -and -Not $GitRemoteURL) {
            Write-Warning "Remote URL Required as repo does not have any origin"
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
            Write-Warning "Branch Has Remote Tracking" -InformationAction Continue
            git pull
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

if ($GitHubCLIExists) {
    function New-PullRequest {
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

        param(
            [Parameter(Mandatory = $true)][string]$RequestTitle,
            [Parameter(Mandatory = $true)][string]$RequestBody,
            [Parameter(Mandatory = $false)][string[]]$Labels,
            [Parameter(Mandatory = $false)][string]$BaseBranch
        )

        # Check to make sure we are in a git controlled folder
        $GitFolder = Get-ChildItem -Path $(Get-Location) -Force -Directory -Filter ".git"
        if ($GitFolder.Count -eq 0) {
            Write-Warning "Not a git Repository"
            return
        }

        # Check to make sure we are not on the 'main' branch.
        $CurrentBranch = ((git branch) | Where-Object { $_ -like '*`**' }).Replace('*', '').Trim()
        if ((($CurrentBranch -eq 'main') -or ($CurrentBranch -eq 'master')) -and -Not $BaseBranch) {
            Write-Warning "Branch is currently on $CurrentBranch. This is the default branch."
            Write-Warning "Run this command to create a pull request from a non default branch or specify a base branch"
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
}

function Merge-PullRequest {
    <#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER PullRequestNumber
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>

    param(
        [Parameter(Mandatory = $false)][int]$PullRequestNumber
    )

    if (-Not $PullRequestNumber) {
        Write-Warning "No Pull Request Number Selected, Please Specify one from the following list"
        gh pr list
        $PullRequestNumber = Read-Host -Prompt "Enter the number of the Pull request you want: "
    }

    gh pr merge $PullRequestNumber --merge --delete-branch
    git pull
}
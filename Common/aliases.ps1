# aliases
$applicationAliases = @{} # Generic ones here

if ($IsWindows) {
    $applicationAliases += @{
        'tf' = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe|C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\tf.EXE|C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe'
        'wm' = 'C:\Program Files (x86)\WinMerge\WinMergeU.exe'
        'ai' = 'C:\ProgramData\.NET Tools\Assembly Information v2.1\AssemblyInformationX64.exe'
    }
}

foreach ($applicationAlias in $applicationAliases.GetEnumerator()) {
    if (Test-Path -Path $applicationAlias.Value) {
        Set-Alias -Name $applicationAlias.Key -Value $applicationAlias.Value
    }
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

if ($null -ne $env:GIT_PROJECT_ROOT_PATH) {

    function Show-Projects {
        <#
.SYNOPSIS
Shows list of folder names in GIT_PROJECT_ROOT_PATH
 .DESCRIPTION
if GIT_PROJECT_ROOT_PATH environment variable is set, this function allows the user to
quickly list all projects in the project root


.EXAMPLE
PS> Show-Projects
#>
        $Projects = (Get-ChildItem -Path $env:GIT_PROJECT_ROOT_PATH).Name

        if ($Projects) {
            $Projects
        }
        else {
            Write-Warning "No projects to show."
        }
    }

    function Start-Work {
        <#
.SYNOPSIS
Sets Location to GIT_PROJECT_ROOT_PATH\Specified Project Name
.DESCRIPTION
if GIT_PROJECT_ROOT_PATH environment variable is set, this function allows the user to
switch location to the root of a project by name.

.PARAMETER ProjectName
The name of the project to push-location into the root of.

.EXAMPLE
PS> Start-Work MyProject
"Setting Location to GIT_PROJECT_ROOT_PATH\MyProject"
#>
        [CmdletBinding()]
        Param()

        DynamicParam {
            $attributes = new-object System.Management.Automation.ParameterAttribute
            $attributes.Mandatory = $false

            $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)

            $validateSet = Show-Projects
            if ($validateSet.count -ne 0) {
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($validateSet)
                $AttributeCollection.Add($ValidateSetAttribute)
            }

            $dynamicParameter = new-object -Type System.Management.Automation.RuntimeDefinedParameter("ProjectName", [string], $attributeCollection)
            $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add("ProjectName", $dynamicParameter)

            return $paramDictionary
        }

        End {
            if($PSBoundParameters['ProjectName'])
            {
                $ProjectPath = "$($env:GIT_PROJECT_ROOT_PATH)\$($PSBoundParameters['ProjectName'])"
                if (Test-Path -Path $ProjectPath) {
                    Write-Output -InputObject "Switching Location to $ProjectPath"
                    Push-Location -Path $ProjectPath
                }
                else {
                    Write-Warning -Message "$ProjectPath does not exist"
                }
            }
            else {
                Set-Location $env:GIT_PROJECT_ROOT_PATH
            }
        }
    }

    Set-Alias -Name workon -Value Start-Work
}
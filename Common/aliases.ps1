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

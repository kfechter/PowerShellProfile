# Pretty prompt does not work except in Windows Terminal
if ([bool]($env:WT_Session)) {
    Set-Theme Paradox
}
else {
    function prompt {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '', Scope = 'Function')]
        param()
        Write-Warning 'Test For Non WT shells'
    }
}


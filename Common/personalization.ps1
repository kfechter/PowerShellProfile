# Pretty prompt does not work except in Windows Terminal
if ($global:IsWindowsTerminal) {
        Set-Theme Paradox
}
else {
    function prompt {
        Write-Warning 'Test For Non WT shells'
    }
}


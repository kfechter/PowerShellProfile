# Pretty prompt does not work except in Windows Terminal
if ([bool]($env:WT_Session)) {
    Set-Theme Paradox
}
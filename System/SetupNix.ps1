# Install Linux Applications, Configure shell, git, ssh, gpg.
if (Test-Path -Path '/home/.setupcomplete') {
    return
}

if (-Not ((id -u) -eq 0)) {
    Write-Warning 'To complete system setup, powershell must be run as root.'
    return
}
if ($IsWindows) {
    . "$PSScriptRoot\SetupWindows.ps1"
}
else {
    . "$PSScriptRoot\SetupNix.ps1"
}

if ($IsLinux) {
    # Linux Setup Stuff Here (Although linux setup might need to be bootstrapped as a default *nix wont have the power)
    # Bootstrap script should install powershell and dotnet core, then handoff to the profile
    # Install my standard gamut of dev applications and set up anything else
}
elseif ($IsWindows) {
    # Do Windows things, requires pwsh core though to bootstrap this (Add to readme)

    if ($IsDefinedSystem) {
        # Defined Systems are those that should have the full suite of windows features turned on.
        # Containers, Hyper-V, WSL
        # This if should only add features/software to a list rather than anything else to prevent script dup
    }
}
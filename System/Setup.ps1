# Configures a new system the first time the profile is loaded, if not already configured. Also requires Admin\
function Test-AdminPrivilege {
    if ($IsWindows) {
        return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    else {
        return ((id -u) -eq 0)
    }
}

if(-Not (Test-AdminPrivilege)) {
    Write-Warning "This setup must be run as admin, run powershell core once as admin to complete."
}

if ($IsLinux) {
    # Linux Setup Stuff Here (Although linux setup might need to be bootstrapped as a default *nix wont have the power)
}
elseif ($IsWindows) {
    # Do Windows things, requires pwsh core though to bootstrap this (Add to readme)
    $WindowsSystemDefinitionList = @('LR0BX58X')
    $IsDefinedSystem = (Get-WMIObject Win32_Bios | Select-Object SerialNumber).SerialNumber -in $WindowsSystemDefinitionList

    if ($IsDefinedSystem) {
        # Defined Systems are those that should have the full suite of windows features turned on.
        # Containers, Hyper-V, WSL
        # This if should only add features/software to a list rather than anything else to prevent script dup
    }
}
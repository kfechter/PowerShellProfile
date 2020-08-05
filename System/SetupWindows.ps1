# Check for existence of setup completion file, return if setup has already run
if (Test-Path 'C:\Temp\.setupcomplete') {
    return
}

if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning 'To complete system setup, powershell must be run as admin.'
    return
}

# Configuration Map for systems and the Windows Features to enable for them
$RegisteredSystems = @{
    'LR0BX58X' = @{
        'WindowsFeatures' = @()
    }
}

# Base Settings
$BaseWindowsFeatures = @()

function Complete-SystemSetup {
    # Try and get the system serial number.
    $SystemSerial = (Get-WMIObject Win32_Bios | Select-Object SerialNumber).SerialNumber

    if ($RegisteredSystems.ContainsKey($SystemSerial)) {
        $WindowsFeatures = $RegisteredSystems[$SystemSerial].Value.WindowsFeatures
        Write-Information "Installing Features: $WindowsFeatures"
    }
    else {
        $WindowsFeatures = $BaseWindowsFeatures
        Write-Information "Installing Features: $WindowsFeatures"
    }
}



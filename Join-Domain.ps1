<#
.SYNOPSIS
    Joins an Azure Windows VM to an Active Directory domain.
.DESCRIPTION
    This script is executed via the Azure Custom Script Extension during VM provisioning.
#>

param (
    [string]$DomainName,
    [string]$DomainAdminUser,
    [SecureString]$DomainAdminPassword,
    [string]$OUPath
)

try {
    # Convert password to secure string and create credentials
    $SecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainCredential = New-Object System.Management.Automation.PSCredential($DomainAdminUser, $SecurePassword)

    # Set execution policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

    # Join the domain (with OU path if specified)
    $joinParams = @{
        DomainName = $DomainName
        Credential = $DomainCredential
        Force = $true
        ErrorAction = 'Stop'
    }
    
    if ($OUPath) {
        $joinParams['OUPath'] = $OUPath
    }

    Add-Computer @joinParams

    # Set DNS suffix
    $interface = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if ($interface) {
        Set-DnsClient -InterfaceIndex $interface.InterfaceIndex -ConnectionSpecificSuffix $DomainName
    }

    # Enable PowerShell Remoting
    Enable-PSRemoting -Force

    # Output success and schedule reboot
    Write-Output "Successfully joined domain '$DomainName'. Rebooting to complete the process..."
    shutdown /r /t 30 /c "Rebooting to complete domain join"
    
    exit 0
}
catch {
    Write-Error "Domain join failed: $_"
    exit 1
}
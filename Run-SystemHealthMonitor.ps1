<# 
.SYNOPSIS
    PowerShell System Health Monitor and Auto-Remediation Tool

.DESCRIPTION
    Checks local system health metrics, verifies monitored services,
    attempts basic remediation, reviews recent event log errors, and
    writes a log file.

.NOTES
    Author: Josh Frometa
    Version: 1.0
    For use in Windows PowerShell 5.1 and later (including PowerShell Core on Windows)
#>

# Use $PWD instead of $PSScriptRoot for manually running, but $PSScriptRoot for scheduled script use
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [int]$HoursToCheck = 24,
    [switch]$Remediate,
    [switch]$IncludeAutomatic
)

# Main Execution Block
try {
    # Load all function scripts from the Functions directory
    Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }

    # Step 1: Initialize configuration and paths
    $config = Initialize-HealthMonitor -ComputerName $ComputerName

    # Step 2: Collect health metrics
    $healthMetrics = Get-HealthMetrics -Config $config

    # Step 3: Check monitored services
    if ($IncludeAutomatic) {
        $serviceResults = Get-ServiceHealth `
    -ServiceNames $config.MonitoredServices `
    -IncludeAutomatic
    }
    else {
        $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
    }

    # Step 4: Attempt remediation if requested
    if ($Remediate) {
        $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
    }

    # Step 5: Get recent event log errors
    $eventResults = @(Get-RecentEventErrors -HoursToCheck $HoursToCheck)

    # Step 6: Determine overall health status
    $overallStatus = Get-OverallStatus `
    -HealthMetrics $healthMetrics `
    -ServiceResults $serviceResults `
    -EventResults $eventResults

    # Step 7: Write log file
    Write-HealthLog `
    -Config $config `
    -HealthMetrics $healthMetrics `
    -ServiceResults $serviceResults `
    -EventResults $eventResults `
    -OverallStatus $overallStatus

    # Step 8: Generate HTML report
    # New-HealthHtmlReport `
    # -Config $config `
    # -HealthMetrics $healthMetrics `
    # -ServiceResults $serviceResults `
    # -EventResults $eventResults `
    # -OverallStatus $overallStatus

    # Output overall status to console
    Write-Host "Overall Status: $($overallStatus.Status)" -ForegroundColor Green
    foreach ($reason in $overallStatus.Reasons) {
        Write-Host "- $reason" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "System Health monitor failed: $_"
    exit 1
}
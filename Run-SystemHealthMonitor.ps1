<# 
.SYNOPSIS
    PowerShell System Health Monitor and Auto-Remediation Tool

.DESCRIPTION
    Checks local system health metrics, verifies monitored services,
    attempts basic remediation, reviews recent event log errors,
    writes a log file, and generates an HTML report.

.NOTES
    Author: Josh Frometa
    Version: 1.0
    For use in Windows PowerShell 5.1 and later (including PowerShell Core on Windows)
#>

# Testing Code

# Testing Initialize-HealthMonitor function
# Get-Command Initialize-HealthMonitor
# $config = Initialize-HealthMonitor
# $config | Format-List

#Testing Get-HealthMetrics function
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $healthMetrics | Format-List
# $healthMetrics.DiskResults | Format-Table -AutoSize

# Testing Get-ServiceHealth function
# $config = Initialize-HealthMonitor
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices

# Testing Invoke-ServiceRemediation function
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
# $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
# $serviceResults | Format-Table -AutoSize

# Testing Get-RecentEventErrors function
# $events = Get-RecentEventErrors -HoursToCheck $HoursToCheck
# $events | Select-Object -First 10 | Format-Table -AutoSize

# Testing Get-OverallStatus function
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
# $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
# $EventResults = Get-RecentEventErrors -HoursToCheck $HoursToCheck
# $overallStatus = Get-OverallStatus -HealthMetrics $healthMetrics -ServiceResults $serviceResults -EventResults $EventResults
# $overallStatus | Format-List

# Use $PWD instead of $PSScriptRoot for testing, but switch back to $PSScriptRoot for production use
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [int]$HoursToCheck = 24,
    [switch]$Remediate
)

# Main Execution Block
try {
    # Load all function scripts from the Functions directory
    Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }

    # Step 1: Initialize configuration and paths
    $config = Initialize-HealthMonitor

    # Step 2: Collect health metrics
    $healthMetrics = Get-HealthMetrics -Config $config

    # Step 3: Check monitored services
    $serviceResults = Get-ServiceHealth `
    -ServiceNames $config.MonitoredServices `
    -IncludeAutomatic

    # Step 4: Attempt remediation if requested
    if ($Remediate) {
        $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
    }

    # Step 5: Get recent event log errors
    $eventResults = Get-RecentEventErrors -HoursToCheck $HoursToCheck

    # Step 6: Determine overall health status
    $overallStatus = Get-OverallStatus `
    -HealthMetrics $healthMetrics `
    -ServiceResults $serviceResults `
    -EventResults $eventResults

    # Step 7: Write log file
    # Write-HealthLog `
    # -Config $config `
    # -HealthMetrics $healthMetrics `
    # -ServiceResults $serviceResults `
    # -EventResults $eventResults `
    # -OverallStatus $overallStatus

    # Output overall status to console
    $overallStatus | Format-List
}
catch {
    Write-Error "System Health monitor failed: $_"
    exit 1
}
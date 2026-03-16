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
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-HealthMonitor {
    [CmdletBinding()]
    param()

    $runTime = Get-Date
    $computerName = $env:COMPUTERNAME

    $basePath = "C:\SystemHealthMonitor"
    $logDirectory = Join-Path $basePath "Logs"
    $reportDirectory = Join-Path $basePath "Reports"

    foreach ($path in @($basePath, $logDirectory, $reportDirectory)) {
        if (-not (Test-Path -Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }

    $timeStamp = $runTime.ToString("yyyyMMdd_HHmmss")
    $logFile = Join-Path $logDirectory "HealthLog_$timeStamp.txt"
    $htmlReportFile = Join-Path $reportDirectory "HealthReport_$timeStamp.html"

    $config = [PSCustomObject]@{
        ComputerName                  = $computerName
        RunTime                       = $runTime
        TimeStamp                     = $timeStamp
        BasePath                      = $basePath
        LogDirectory                  = $logDirectory
        ReportDirectory               = $reportDirectory
        LogFile                       = $logFile
        HtmlReportFile                = $htmlReportFile
        CpuThreshold                  = 80
        CpuCriticalThreshold          = 95
        MemoryThreshold               = 80
        MemoryCriticalThreshold       = 95
        DiskFreeThresholdPercent      = 20
        CriticalDiskFreeThresholdPercent = 10
        EventLookbackMinutes          = 30
        WarningEventThreshold         = 1
        CriticalEventThreshold        = 6
        MonitoredServices             = @(
            "Spooler",
            "wuauserv",
            "BITS",
            "LanmanServer"
        )
    }

    return $config
}

function Get-HealthMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config
    )

    # CPU
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3
    $cpuPercent = [math]::Round(
        ($cpuCounter.CounterSamples.CookedValue | Measure-Object -Average).Average,
        2
    )

    # Memory
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemoryKB = [double]$osInfo.TotalVisibleMemorySize
    $freeMemoryKB = [double]$osInfo.FreePhysicalMemory
    $usedMemoryPercent = [math]::Round((($totalMemoryKB - $freeMemoryKB) / $totalMemoryKB) * 100, 2)

    # Disks
    $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3"

    $diskResults = foreach ($disk in $diskInfo) {
        $sizeGB = [math]::Round(($disk.Size / 1GB), 2)
        $freeGB = [math]::Round(($disk.FreeSpace / 1GB), 2)
        $percentFree = if ($disk.Size -gt 0) {
            [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
        }
        else {
            0
        }

        $percentUsed = [math]::Round((100 - $percentFree), 2)

        $diskStatus = if ($percentFree -lt $Config.CriticalDiskFreeThresholdPercent) {
            "Critical"
        }
        elseif ($percentFree -lt $Config.DiskFreeThresholdPercent) {
            "Warning"
        }
        else {
            "Healthy"
        }

        [PSCustomObject]@{
            DriveLetter = $disk.DeviceID
            VolumeName  = $disk.VolumeName
            SizeGB      = $sizeGB
            FreeGB      = $freeGB
            PercentFree = $percentFree
            PercentUsed = $percentUsed
            Status      = $diskStatus
        }
    }

    $cpuStatus = if ($cpuPercent -ge $Config.CpuCriticalThreshold) {
        "Critical"
    }
    elseif ($cpuPercent -ge $Config.CpuThreshold) {
        "Warning"
    }
    else {
        "Healthy"
    }

    $memoryStatus = if ($usedMemoryPercent -ge $Config.MemoryCriticalThreshold) {
        "Critical"
    }
    elseif ($usedMemoryPercent -ge $Config.MemoryThreshold) {
        "Warning"
    }
    else {
        "Healthy"
    }

    return [PSCustomObject]@{
        CpuPercent        = $cpuPercent
        CpuStatus         = $cpuStatus
        MemoryPercent     = $usedMemoryPercent
        MemoryStatus      = $memoryStatus
        DiskResults       = $diskResults
    }
}

function Get-ServiceHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ServiceNames
    )

    $serviceResults = foreach ($serviceName in $ServiceNames) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop

            [PSCustomObject]@{
                ServiceName           = $service.Name
                DisplayName           = $service.DisplayName
                CurrentStatus         = [string]$service.Status
                StartType             = "Unknown"
                NeedsRemediation      = ($service.Status -ne 'Running')
                RemediationAttempted  = $false
                RemediationSucceeded  = $false
                Notes                 = if ($service.Status -eq 'Running') { "Service is running." } else { "Service is not running." }
            }
        }
        catch {
            [PSCustomObject]@{
                ServiceName           = $serviceName
                DisplayName           = $serviceName
                CurrentStatus         = "NotFound"
                StartType             = "Unknown"
                NeedsRemediation      = $false
                RemediationAttempted  = $false
                RemediationSucceeded  = $false
                Notes                 = "Service not found."
            }
        }
    }

    return $serviceResults
}

function Invoke-ServiceRemediation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ServiceResults
    )

    $updatedServiceResults = foreach ($serviceResult in $ServiceResults) {
        if ($serviceResult.NeedsRemediation -and $serviceResult.CurrentStatus -ne 'NotFound') {
            $serviceResult.RemediationAttempted = $true

            try {
                Start-Service -Name $serviceResult.ServiceName -ErrorAction Stop
                Start-Sleep -Seconds 2

                $updatedService = Get-Service -Name $serviceResult.ServiceName -ErrorAction Stop

                if ($updatedService.Status -eq 'Running') {
                    $serviceResult.CurrentStatus = [string]$updatedService.Status
                    $serviceResult.RemediationSucceeded = $true
                    $serviceResult.Notes = "Service was stopped and restarted successfully."
                }
                else {
                    $serviceResult.CurrentStatus = [string]$updatedService.Status
                    $serviceResult.RemediationSucceeded = $false
                    $serviceResult.Notes = "Restart was attempted, but service is not running."
                }
            }
            catch {
                $serviceResult.RemediationSucceeded = $false
                $serviceResult.Notes = "Failed to restart service. Error: $($_.Exception.Message)"
            }
        }

        $serviceResult
    }

    return $updatedServiceResults
}

function Get-RecentEventErrors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$LookbackMinutes,
        [Parameter(Mandatory)]
        [int]$WarningThreshold,
        [Parameter(Mandatory)]
        [int]$CriticalThreshold
    )

    $startTime = (Get-Date).AddMinutes(-$LookbackMinutes)

    $events = Get-WinEvent -FilterHashtable @{
        LogName   = @("System", "Application")
        StartTime = $startTime
        Level     = 2
    } -ErrorAction SilentlyContinue

    if (-not $events) {
        $events = @()
    }

    $systemErrorCount = @($events | Where-Object { $_.LogName -eq 'System' }).Count
    $applicationErrorCount = @($events | Where-Object { $_.LogName -eq 'Application' }).Count
    $totalErrorCount = @($events).Count

    $status = if ($totalErrorCount -ge $CriticalThreshold) {
        "Critical"
    }
    elseif ($totalErrorCount -ge $WarningThreshold) {
        "Warning"
    }
    else {
        "Healthy"
    }

    return [PSCustomObject]@{
        LookbackMinutes       = $LookbackMinutes
        StartTime             = $startTime
        TotalErrorCount       = $totalErrorCount
        SystemErrorCount      = $systemErrorCount
        ApplicationErrorCount = $applicationErrorCount
        Status                = $status
    }
}

function Get-OverallStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$HealthMetrics,
        [Parameter(Mandatory)]
        [array]$ServiceResults,
        [Parameter(Mandatory)]
        [pscustomobject]$EventResults
    )

    $statusReasons = New-Object System.Collections.Generic.List[string]
    $overallStatus = "Healthy"

    if ($HealthMetrics.CpuStatus -eq 'Warning') {
        $statusReasons.Add("CPU usage exceeded warning threshold.")
        $overallStatus = "Warning"
    }
    elseif ($HealthMetrics.CpuStatus -eq 'Critical') {
        $statusReasons.Add("CPU usage exceeded critical threshold.")
        $overallStatus = "Critical"
    }

    if ($HealthMetrics.MemoryStatus -eq 'Warning' -and $overallStatus -ne 'Critical') {
        $statusReasons.Add("Memory usage exceeded warning threshold.")
        $overallStatus = "Warning"
    }
    elseif ($HealthMetrics.MemoryStatus -eq 'Critical') {
        $statusReasons.Add("Memory usage exceeded critical threshold.")
        $overallStatus = "Critical"
    }

    foreach ($disk in $HealthMetrics.DiskResults) {
        if ($disk.Status -eq 'Warning' -and $overallStatus -ne 'Critical') {
            $statusReasons.Add("Disk $($disk.DriveLetter) is low on free space.")
            $overallStatus = "Warning"
        }
        elseif ($disk.Status -eq 'Critical') {
            $statusReasons.Add("Disk $($disk.DriveLetter) is critically low on free space.")
            $overallStatus = "Critical"
        }
    }

    foreach ($service in $ServiceResults) {
        if ($service.CurrentStatus -eq 'NotFound' -and $overallStatus -ne 'Critical') {
            $statusReasons.Add("Service $($service.ServiceName) was not found.")
            $overallStatus = "Warning"
        }
        elseif ($service.RemediationAttempted -and $service.RemediationSucceeded -and $overallStatus -ne 'Critical') {
            $statusReasons.Add("Service $($service.ServiceName) was stopped and restarted successfully.")
            $overallStatus = "Warning"
        }
        elseif ($service.RemediationAttempted -and -not $service.RemediationSucceeded) {
            $statusReasons.Add("Service $($service.ServiceName) failed remediation.")
            $overallStatus = "Critical"
        }
    }

    if ($EventResults.Status -eq 'Warning' -and $overallStatus -ne 'Critical') {
        $statusReasons.Add("Recent warning-level event error threshold was reached.")
        $overallStatus = "Warning"
    }
    elseif ($EventResults.Status -eq 'Critical') {
        $statusReasons.Add("Recent critical-level event error threshold was reached.")
        $overallStatus = "Critical"
    }

    if ($statusReasons.Count -eq 0) {
        $statusReasons.Add("No issues detected.")
    }

    return [PSCustomObject]@{
        OverallStatus = $overallStatus
        Reasons       = $statusReasons
    }
}

function Write-HealthLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config,
        [Parameter(Mandatory)]
        [pscustomobject]$HealthMetrics,
        [Parameter(Mandatory)]
        [array]$ServiceResults,
        [Parameter(Mandatory)]
        [pscustomobject]$EventResults,
        [Parameter(Mandatory)]
        [pscustomobject]$OverallStatus
    )

    $logLines = @()
    $logLines += "============================================"
    $logLines += "System Health Monitor Run"
    $logLines += "Computer Name: $($Config.ComputerName)"
    $logLines += "Run Time: $($Config.RunTime)"
    $logLines += "Overall Status: $($OverallStatus.OverallStatus)"
    $logLines += "--------------------------------------------"
    $logLines += "CPU Usage: $($HealthMetrics.CpuPercent)% [$($HealthMetrics.CpuStatus)]"
    $logLines += "Memory Usage: $($HealthMetrics.MemoryPercent)% [$($HealthMetrics.MemoryStatus)]"
    $logLines += "--------------------------------------------"
    $logLines += "Disk Results:"

    foreach ($disk in $HealthMetrics.DiskResults) {
        $logLines += "Drive $($disk.DriveLetter): Free $($disk.FreeGB) GB of $($disk.SizeGB) GB | $($disk.PercentFree)% free | Status: $($disk.Status)"
    }

    $logLines += "--------------------------------------------"
    $logLines += "Service Results:"

    foreach ($service in $ServiceResults) {
        $logLines += "$($service.ServiceName): Status=$($service.CurrentStatus) | RemediationAttempted=$($service.RemediationAttempted) | RemediationSucceeded=$($service.RemediationSucceeded) | Notes=$($service.Notes)"
    }

    $logLines += "--------------------------------------------"
    $logLines += "Recent Event Errors:"
    $logLines += "Lookback Minutes: $($EventResults.LookbackMinutes)"
    $logLines += "Total Errors: $($EventResults.TotalErrorCount)"
    $logLines += "System Errors: $($EventResults.SystemErrorCount)"
    $logLines += "Application Errors: $($EventResults.ApplicationErrorCount)"
    $logLines += "Event Status: $($EventResults.Status)"
    $logLines += "--------------------------------------------"
    $logLines += "Status Reasons:"

    foreach ($reason in $OverallStatus.Reasons) {
        $logLines += "- $reason"
    }

    $logLines += "============================================"

    $logLines | Out-File -FilePath $Config.LogFile -Encoding UTF8
}

function New-HealthHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config,
        [Parameter(Mandatory)]
        [pscustomobject]$HealthMetrics,
        [Parameter(Mandatory)]
        [array]$ServiceResults,
        [Parameter(Mandatory)]
        [pscustomobject]$EventResults,
        [Parameter(Mandatory)]
        [pscustomobject]$OverallStatus
    )

    $statusColor = switch ($OverallStatus.OverallStatus) {
        'Healthy'  { 'green' }
        'Warning'  { 'orange' }
        'Critical' { 'red' }
        default    { 'gray' }
    }

    $diskRows = foreach ($disk in $HealthMetrics.DiskResults) {
        "<tr><td>$($disk.DriveLetter)</td><td>$($disk.VolumeName)</td><td>$($disk.SizeGB)</td><td>$($disk.FreeGB)</td><td>$($disk.PercentFree)%</td><td>$($disk.Status)</td></tr>"
    }

    $serviceRows = foreach ($service in $ServiceResults) {
        "<tr><td>$($service.ServiceName)</td><td>$($service.DisplayName)</td><td>$($service.CurrentStatus)</td><td>$($service.RemediationAttempted)</td><td>$($service.RemediationSucceeded)</td><td>$($service.Notes)</td></tr>"
    }

    $reasonRows = foreach ($reason in $OverallStatus.Reasons) {
        "<li>$reason</li>"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>System Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #222; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .status-badge {
            display: inline-block;
            padding: 8px 14px;
            color: white;
            background-color: $statusColor;
            border-radius: 6px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <h1>System Health Report</h1>
    <p><strong>Computer Name:</strong> $($Config.ComputerName)</p>
    <p><strong>Run Time:</strong> $($Config.RunTime)</p>
    <p><strong>Overall Status:</strong> <span class="status-badge">$($OverallStatus.OverallStatus)</span></p>

    <h2>System Metrics</h2>
    <p><strong>CPU Usage:</strong> $($HealthMetrics.CpuPercent)% ($($HealthMetrics.CpuStatus))</p>
    <p><strong>Memory Usage:</strong> $($HealthMetrics.MemoryPercent)% ($($HealthMetrics.MemoryStatus))</p>

    <h2>Disk Results</h2>
    <table>
        <tr>
            <th>Drive</th>
            <th>Volume Name</th>
            <th>Size (GB)</th>
            <th>Free (GB)</th>
            <th>Percent Free</th>
            <th>Status</th>
        </tr>
        $($diskRows -join "`n")
    </table>

    <h2>Service Results</h2>
    <table>
        <tr>
            <th>Service Name</th>
            <th>Display Name</th>
            <th>Current Status</th>
            <th>Remediation Attempted</th>
            <th>Remediation Succeeded</th>
            <th>Notes</th>
        </tr>
        $($serviceRows -join "`n")
    </table>

    <h2>Recent Event Errors</h2>
    <p><strong>Lookback Minutes:</strong> $($EventResults.LookbackMinutes)</p>
    <p><strong>Total Errors:</strong> $($EventResults.TotalErrorCount)</p>
    <p><strong>System Errors:</strong> $($EventResults.SystemErrorCount)</p>
    <p><strong>Application Errors:</strong> $($EventResults.ApplicationErrorCount)</p>
    <p><strong>Event Status:</strong> $($EventResults.Status)</p>

    <h2>Status Reasons</h2>
    <ul>
        $($reasonRows -join "`n")
    </ul>
</body>
</html>
"@

    $html | Out-File -FilePath $Config.HtmlReportFile -Encoding UTF8
}

# =========================
# Main Execution Workflow
# =========================

try {
    $config = Initialize-HealthMonitor

    $healthMetrics = Get-HealthMetrics -Config $config

    $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices

    $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults

    $eventResults = Get-RecentEventErrors `
        -LookbackMinutes $config.EventLookbackMinutes `
        -WarningThreshold $config.WarningEventThreshold `
        -CriticalThreshold $config.CriticalEventThreshold

    $overallStatus = Get-OverallStatus `
        -HealthMetrics $healthMetrics `
        -ServiceResults $serviceResults `
        -EventResults $eventResults

    Write-HealthLog `
        -Config $config `
        -HealthMetrics $healthMetrics `
        -ServiceResults $serviceResults `
        -EventResults $eventResults `
        -OverallStatus $overallStatus

    New-HealthHtmlReport `
        -Config $config `
        -HealthMetrics $healthMetrics `
        -ServiceResults $serviceResults `
        -EventResults $eventResults `
        -OverallStatus $overallStatus

    Write-Host "System Health Monitor Complete" -ForegroundColor Green
    Write-Host "Computer Name: $($config.ComputerName)"
    Write-Host "Run Time: $($config.RunTime)"
    Write-Host "Overall Status: $($overallStatus.OverallStatus)"
    Write-Host "Log File: $($config.LogFile)"
    Write-Host "Report File: $($config.HtmlReportFile)"
}
catch {
    Write-Error "System Health Monitor failed: $($_.Exception.Message)"
}
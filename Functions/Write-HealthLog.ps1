function Write-HealthLog {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        [PSCustomObject]$HealthMetrics,
        [PSCustomObject[]]$ServiceResults,
        [PSCustomObject[]]$EventResults,
        [PSCustomObject]$OverallStatus
    )
    $logLines = @()
    $logLines += "========== System Health Monitor Log =========="
    $logLines += "Run Time: $($Config.RunTime)"
    $logLines += "Computer Name: $($Config.ComputerName)"
    $logLines += "Overall Status: $($OverallStatus.OverallHealth)"
    $logLines += ""

    $logLines += "Status Reasons:"
    foreach ($reason in $OverallStatus.Reasons) {
        $logLines += " - $reason"
    }
    $logLines += ""

    $logLines += "System Health Metrics:"
    $logLines += "CPU Usage: $($HealthMetrics.CpuPercent)% [$($HealthMetrics.CpuStatus)]"
    $logLines += "Memory Usage: $($HealthMetrics.PercentUsed)% [$($HealthMetrics.Status)]"
    $logLines += ""

    $logLines += "Disk Usage:"
    foreach ($disk in $HealthMetrics.DiskResults) {
        $logLines += " - Drive $($disk.DriveLetter) $($disk.SizeGB - $disk.FreeGB)GB used of $($disk.SizeGB)GB ($($disk.PercentFree)% free) | [$($disk.Status)]"
    }
    $logLines += ""

    $logLines += "Service Results:"
    foreach ($service in $ServiceResults) {
        if ($service.RemediationNeeded) {
            $logLines += "Service: $($service.ServiceName) requires remediation. `
            Attempted: $($service.RemediationAttempted) `
            Success: $($service.RemediationSuccess) `
            Notes: $($service.Notes)"
        }
         else {
            $logLines += "Service: $($service.ServiceName) is healthy. `
            Status: $($service.Status)"
        }
    }
    $logLines += ""

    $logLines += "Recent Event Errors:"
    if ($EventResults.Count -ge 0) {
              foreach ($e in $EventResults) {
            $logLines += "Log: $($e.LogName) | Time: $($e.Time) | ID: $($e.EventId) | Provider: $($e.ProviderName) `
            Message: $($e.Message)"
        }
    } 
    else { 
        $logLines += "No recent event errors found."
    }
    $logLines += ""
    $logLines += "=============================================="

    $logLines | Out-File -Append "$($Config.LogFile)"
}
function Write-HealthLog {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HealthMetrics,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$ServiceResults,

        [PSCustomObject[]]$EventResults = @(),
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$OverallStatus
    )
    $logLines = @()
    $logLines += "======================================================="
    $logLines += "               System Health Monitor Log"
    $logLines += "======================================================="
    $logLines += "Run Time: $($Config.RunTime)"
    $logLines += "Computer Name: $($Config.ComputerName)"
    $logLines += "Overall Status: $($OverallStatus.Status)"
    $logLines += ""

    $StatusTitle= "Status Reasons:"
        $logLines += $StatusTitle
        $logLines += "-" * $StatusTitle.Length
    foreach ($reason in $OverallStatus.Reasons) {
        $logLines += "- $reason"
    }
    $logLines += ""

    $SystemHealthTitle = "System Health Metrics:"
    $logLines += $SystemHealthTitle
    $logLines += "-" * $SystemHealthTitle.Length
    $logLines += "CPU Usage: $($HealthMetrics.CpuPercent)% [$($HealthMetrics.CpuStatus)]"
    $logLines += "Memory Usage: $($HealthMetrics.MemoryPercent)% [$($HealthMetrics.MemoryStatus)]"
    $logLines += ""

    $DiskTitle = "Disk Usage:"
    $logLines += $DiskTitle
    $logLines += "-" * $DiskTitle.Length
    foreach ($disk in $HealthMetrics.DiskResults) {
        $logLines += "- Drive $($disk.DriveLetter) $([math]::Round($disk.SizeGB - $disk.FreeGB, 2))GB used of $($disk.SizeGB)GB ($($disk.PercentFree)% free) | [$($disk.Status)]"
    }
    $logLines += ""

    $ServiceTitle = "Service Results:"
    $logLines += $ServiceTitle
    $logLines += "-" * $ServiceTitle.Length
    foreach ($service in $ServiceResults) {
        if ($service.NeedsRemediation -and $service.RemediationAttempted) {
            $logLines += "Service: $($service.ServiceName) requires remediation. `
Attempted: $($service.RemediationAttempted) `
Success: $($service.RemediationSucceeded) `
Notes: $($service.Notes)"
            $logLines += ""
        }
        elseif ($service.NeedsRemediation -and $service.RemediationAttempted -eq $false) {
            $logLines += "Service: $($service.ServiceName) requires remediation. `
Remediation Attempted: $($service.RemediationAttempted) `
Notes: $($service.Notes)"
            $logLines += ""
        }
         else {
            $logLines += "Service: $($service.ServiceName) is healthy. `
Status: $($service.CurrentStatus)"
            $logLines += ""
        }
    }
    $logLines += ""

    $EventTitle = "Recent Event Errors:"
    $logLines += $EventTitle
    $logLines += "-" * $EventTitle.Length
    if ($EventResults.Count -gt 0) {
              foreach ($e in $EventResults) {
            $logLines += "Log: $($e.LogName) | Time: $($e.TimeCreated) | ID: $($e.Id) | Provider: $($e.ProviderName) `
Message: $($e.Message)"
            $logLines += ""
        }
    } 
    else { 
        $logLines += "No recent event errors found."
    }
    $logLines += ""
    $logLines += "=============================================="

    $logLines | Out-File -Append "$($Config.LogFile)"
}
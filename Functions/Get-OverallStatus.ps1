function Get-OverallStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [pscustomobject]$HealthMetrics,

        [Parameter(Mandatory=$true)]
        [object[]]$ServiceResults,

        [Parameter(Mandatory=$true)]
        [object[]]$EventResults
    )

    $overallStatus = "Healthy"
    $reasons = @()

    # Check CPU
    if ($healthMetrics.CpuStatus -eq "Critical") {
        $overallStatus = "Critical"
        $reasons += "CPU usage is in a Critical state at $($healthMetrics.CpuUsage)%"
    }
    elseif ($healthMetrics.CpuStatus -eq "Warning" -and $overallStatus -ne "Critical") {
        $overallStatus = "Warning"
        $reasons += "CPU usage is in a Warning state at $($healthMetrics.CpuUsage)%"
    }

    # Check Memory
    if ($healthMetrics.MemoryStatus -eq "Critical") {
        $overallStatus = "Critical"
        $reasons += "Memory usage is in a Critical state at $($healthMetrics.MemoryUsage)%"
    }
    elseif ($healthMetrics.MemoryStatus -eq "Warning" -and $overallStatus -ne "Critical") {
        $overallStatus = "Warning"
        $reasons += "Memory usage is in a Warning state at $($healthMetrics.MemoryUsage)%"
    }

    # Check Disk
    if ($healthMetrics.DiskStatus -eq "Critical") {
        $overallStatus = "Critical"
        $reasons += "Disk usage is in a Critical state at $($healthMetrics.DiskUsage)% full"
    }
    elseif ($healthMetrics.DiskStatus -eq "Warning" -and $overallStatus -ne "Critical") {
        $overallStatus = "Warning"
        $reasons += "Disk usage is in a Warning state at $($healthMetrics.DiskUsage)% full"
    }

    # Check Services
    foreach ($service in $serviceResults) {
        if ($service.RemediationAttempted -and -not $service.RemediationSucceeded) {
            $overallStatus = "Critical"
            $reasons += "Service '$($service.ServiceName)' is not running and remediation failed"
        }
        elseif ($service.NeedsRemediation -and $service.RemediationSucceeded -and $overallStatus -ne "Critical") {
            $overallStatus = "Warning"
            $reasons += "Service '$($service.ServiceName)' was not running but remediation succeeded"
        }
        elseif ($service.CurrentStatus -eq "NotFound" -and $overallStatus -ne "Critical") {
            $overallStatus = "Warning"
            $reasons += "Service '$($service.ServiceName)' was not found."
        }
    }

    # Check Event Log Errors
    if ($EventResults.Count -ge 10) {
        $overallStatus = "Critical"
        $reasons += "$($EventResults.Count) recent error events were found"
    }
    elseif ($EventResults.Count -ge 1 -and $overallStatus -ne "Critical") {
        $overallStatus = "Warning"
        if ($EventResults.Count -eq 1) {
            $reasons += "1 recent error event was found."
        }
        else {
            $reasons += "$($EventResults.Count) recent error events were found."
        }
    }
    if (-not $reasons) {
        $reasons += "No issues detected."
    }

    [PSCustomObject]@{
        Status = $overallStatus
        Reasons = $reasons
    }
}
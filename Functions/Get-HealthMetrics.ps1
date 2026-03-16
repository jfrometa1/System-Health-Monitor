function Get-HealthMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Config
    )
    # Get average CPU usage across 3 samples
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3
    $cpuPercent = [math]::Round(
        ($cpuCounter.CounterSamples.CookedValue | Measure-Object -Average).Average, 2
    )
    # Get total physical memory and available memory
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemoryKB = [double]$osInfo.TotalVisibleMemorySize
    $freeMemoryKB = [double]$osInfo.FreePhysicalMemory
    $usedMemoryPercent = [math]::Round((($totalMemoryKB - $freeMemoryKB) / $totalMemoryKB) * 100, 2)

    # Get fixed disk information
    $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
    $diskResults = foreach ($disk in $diskInfo) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $percentFree = if ($disk.Size -gt 0) {
            [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
        } else {
            0
        }
        $percentUsed = [math]::Round(100 - $percentFree, 2)
        $diskStatus = if ($percentFree -lt $Config.DiskCriticalThresholdPercent) {
            "Critical"
        } elseif ($percentFree -lt $Config.DiskWarningThresholdPercent) {
            "Warning"
        } else {
            "Healthy"
        }
        [PSCustomObject]@{
            DriveLetter = $disk.DeviceID
            VolumeName = $disk.VolumeName
            SizeGB = $sizeGB
            FreeGB = $freeGB
            PercentFree = $percentFree
            PercentUsed = $percentUsed
            Status = $diskStatus

        }
    }
    $cpuStatus = if ($cpuPercent -ge $Config.CpuCriticalThreshold) {
        "Critical"
    } elseif ($cpuPercent -ge $Config.CpuWarningThreshold) {
        "Warning"
    } else {
        "Healthy"
    }
    $memoryStatus = if ($usedMemoryPercent -ge $Config.MemoryCriticalThreshold) {
        "Critical"
    } elseif ($usedMemoryPercent -ge $Config.MemoryWarningThreshold) {
        "Warning"
    } else {
        "Healthy"
    }
    [PSCustomObject]@{
        CpuPercent = $cpuPercent
        CpuStatus = $cpuStatus
        MemoryPercent = $usedMemoryPercent
        MemoryStatus = $memoryStatus
        DiskResults = $diskResults
    }
}
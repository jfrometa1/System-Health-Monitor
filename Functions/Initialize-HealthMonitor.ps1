function Initialize-HealthMonitor {
    [CmdletBinding()]
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )

$runTime = Get-Date

$basePath = "D:\System-Health-Monitor"
$logDirectory = Join-Path $basePath "Logs"
$reportDirectory = Join-Path $basePath "Reports"

foreach ($path in @($basePath,$logDirectory,$reportDirectory)) {
if (-not (Test-Path $path)) {
New-Item -ItemType Directory -Path $path -Force | Out-Null
}
}

$timeStamp = $runTime.ToString("yyyyMMdd_HHmmss")

$config = [PSCustomObject]@{
ComputerName = $ComputerName
RunTime = $runTime
LogDirectory = $logDirectory
ReportDirectory = $reportDirectory
TimeStamp = $timeStamp
LogFile = Join-Path $logDirectory "HealthLog_$timeStamp.txt"
HtmlReportFile = Join-Path $reportDirectory "HealthReport_$timeStamp.html"
# Threshold Values - Adjust as needed
CpuWarningThreshold = 80
CpuCriticalThreshold = 95
MemoryWarningThreshold = 80
MemoryCriticalThreshold = 95
DiskWarningThresholdPercent = 20
DiskCriticalThresholdPercent = 10
# Monitored Services - Adjust as needed
MonitoredServices = @(
    "Spooler",
    "wuauserv",
    "BITS",
    "WinRM",
    "EventLog",
    "LanmanServer"
    )
}

return $config
}
function Initialize-HealthMonitor {
    [CmdletBinding()]
    param()
$runTime = Get-Date
$computerName = $env:COMPUTERNAME

$basePath = "C:\SystemHealthMonitor"
$logDirectory = Join-Path $basePath "Logs"
$reportDirectory = Join-Path $basePath "Reports"

foreach ($path in @($basePath,$logDirectory,$reportDirectory)) {
if (-not (Test-Path $path)) {
New-Item -ItemType Directory -Path $path -Force | Out-Null
}
}

$timeStamp = $runTime.ToString("yyyyMMdd_HHmmss")

$config = [PSCustomObject]@{
ComputerName = $computerName
RunTime = $runTime
LogDirectory = $logDirectory
ReportDirectory = $reportDirectory
TimeStamp = $timeStamp
LogFile = Join-Path $logDirectory "HealthLog_$timeStamp.txt"
HtmlReportFile = Join-Path $reportDirectory "HealthReport_$timeStamp.html"
}

return $config
}
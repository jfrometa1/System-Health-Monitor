# Testing Code

# Testing Initialize-HealthMonitor function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# Get-Command Initialize-HealthMonitor
# $config = Initialize-HealthMonitor
# $config | Format-List

#Testing Get-HealthMetrics function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $healthMetrics | Format-List
# $healthMetrics.DiskResults | Format-Table -AutoSize

# Testing Get-ServiceHealth function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# $config = Initialize-HealthMonitor
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices

# Testing Invoke-ServiceRemediation function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
# $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
# $serviceResults | Format-Table -AutoSize

# Testing Get-RecentEventErrors function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# $events = Get-RecentEventErrors -HoursToCheck 24
# $events | Select-Object -First 10 | Format-Table -AutoSize

# Testing Get-OverallStatus function
# Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
# $config = Initialize-HealthMonitor
# $healthMetrics = Get-HealthMetrics -Config $config
# $serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
# $serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
# $EventResults = @(Get-RecentEventErrors -HoursToCheck 24)
# $overallStatus = Get-OverallStatus -HealthMetrics $healthMetrics -ServiceResults $serviceResults -EventResults $EventResults
# $overallStatus | Format-List

# Testing Write-HealthLog function
Get-ChildItem "$PWD\Functions\*.ps1" | ForEach-Object { . $_.FullName }
$config = Initialize-HealthMonitor
$healthMetrics = Get-HealthMetrics -Config $config
$serviceResults = Get-ServiceHealth -ServiceNames $config.MonitoredServices
$serviceResults = Invoke-ServiceRemediation -ServiceResults $serviceResults
$eventResults = @(Get-RecentEventErrors -HoursToCheck 24)
$overallStatus = Get-OverallStatus -HealthMetrics $healthMetrics -ServiceResults $serviceResults -EventResults $eventResults
Write-HealthLog `
-Config $config `
-HealthMetrics $healthMetrics `
-ServiceResults $serviceResults `
-EventResults $eventResults `
-OverallStatus $overallStatus

function Get-RecentEventErrors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$HoursToCheck
    )
    $startTime = (Get-Date).AddHours(-$HoursToCheck)
    $eventLogs = @(
        "System",
        "Application"
    )
    $eventResults = foreach ($log in $eventLogs) {
        try{
            Get-WinEvent -FilterHashtable @{
                LogName = $log
                Level = 2 # Error level
                StartTime = $startTime } -ErrorAction Stop |
            Select-Object @{
                Name = "LogName"
                Expression = { $_.LogName }
            }, @{
                Name = "TimeCreated"
                Expression = { $_.TimeCreated }
            }, @{
                Name = "Id"
                Expression = { $_.Id }
            }, @{
                Name = "ProviderName"
                Expression = { $_.ProviderName }
            }, @{
                Name = "Message"
                Expression = { $_.Message }
            }
        }
        catch {
            Write-Warning "Failed to retrieve events from $log log: $($_.Exception.Message)"
        }
    }
    return $eventResults
}
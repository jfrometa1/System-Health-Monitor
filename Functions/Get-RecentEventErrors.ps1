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
    $errorEvents = foreach ($log in $eventLogs) {
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
            if ($_.Exception.Message -like "*No events were found*") {
                # No error events found in this log within the specified time frame, so we can ignore this exception
                Write-Host "No error events found in $log log within the last $HoursToCheck hours." -ForegroundColor Green
            }
            else {
                Write-Warning "Failed to retrieve events from $log log: $($_.Exception.Message)"
            }
        }
    }

    # Check for unexpected reboots (Event ID 6008 in System log)
    $rebootEvents = try {
        Get-WinEvent -FilterHashtable @{
            LogName = "System"
            Id = 6008
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
        if ($_.Exception.Message -notlike "*No events were found*") {
            Write-Warning "Failed to retrieve unexpected reboot events: $($_.Exception.Message)"
        }
        @() # Return empty array if no reboot events found or if there was an error retrieving them
    }
    
    $eventResults = @(
        @($errorEvents) + @($rebootEvents) | Sort-Object LogName, TimeCreated, Id -Descending -Unique
    )

    return $eventResults
}
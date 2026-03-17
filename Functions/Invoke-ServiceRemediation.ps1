function Invoke-ServiceRemediation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$ServiceResults
    )
    foreach ($serviceResult in $ServiceResults) {
        if ($serviceResult.NeedsRemediation) {
            $serviceResult.RemediationAttempted = $true
            try {
                for($i=0; $i -lt 5; $i++) {
                    Start-Service -Name $serviceResult.ServiceName -ErrorAction Stop
                    Start-Sleep -Seconds 1
                    $service = Get-Service -Name $serviceResult.ServiceName
                    if ($service.Status -eq 'Running') {
                        $serviceResult.RemediationSucceeded = $true
                        $serviceResult.CurrentStatus = "Running"
                        $serviceResult.Notes = "Service successfully restarted"
                        break
                    } 
                }
                Start-Service -Name $serviceResult.ServiceName -ErrorAction Stop
                Start-Sleep -Seconds 2
                $service = Get-Service -Name $serviceResult.ServiceName
                if ($service.Status -eq 'Running') {
                    $serviceResult.RemediationSucceeded = $true
                    $serviceResult.CurrentStatus = "Running"
                    $serviceResult.Notes = "Service successfully restarted"
                } 
                else {
                    $serviceResult.Notes = "Restart attempted but service is still not running."
                }
            }
            catch {
                $serviceResult.Notes = "Failed to restart service: $($_.Exception.Message)"
            }
        }
    }
    return $ServiceResults
}
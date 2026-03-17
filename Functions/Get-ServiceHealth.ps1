function Get-ServiceHealth {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]    
        [string[]]$ServiceNames
    )
    $serviceResults = foreach ($ServiceName in $ServiceNames) {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction Stop
            [PSCustomObject]@{
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                OriginalStatus = [string]$service.Status
                CurrentStatus = [string]$service.Status
                NeedsRemediation = $service.Status -ne 'Running'
                RemediationAttempted = $false
                RemediationSucceeded = $false
                Notes = if($service.Status -eq 'Running') {
                    "Service is running."
                } 
                else {
                    "Service is not running."
                }
        }
    }
        catch {
            [PSCustomObject]@{
                ServiceName = $ServiceName
                DisplayName = $ServiceName
                CurrentStatus = "Not Found"
                NeedsRemediation = $false
                RemediationAttempted = $false
                RemediationSucceeded = $false
                Notes = "Service not found."
            }
        }
}
    return $serviceResults
}
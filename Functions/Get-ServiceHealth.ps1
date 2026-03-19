function Get-ServiceHealth {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]    
        [string[]]$ServiceNames,

        [switch]$IncludeAutomatic
    )
    $serviceResults = @()

    $serviceResults += foreach ($ServiceName in $ServiceNames) {
        try {
            $service = Get-Service -Name $ServiceName -ErrorAction Stop
            [PSCustomObject]@{
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                OriginalStatus = [string]$service.Status
                CurrentStatus = [string]$service.Status
                NeedsRemediation = $service.Status -ne 'Running'
                RemediationAttempted = $false
                RemediationSucceeded = $null
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
                OriginalStatus = "Not Found"
                CurrentStatus = "Not Found"
                NeedsRemediation = $false
                RemediationAttempted = $null
                RemediationSucceeded = $""
                Notes = "Service not found."
            }
        }
}
    if ($IncludeAutomatic) {
        $automaticServices = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }
}
    foreach ($service in $automaticServices) {
        if (-not ($serviceResults.ServiceName -contains $service.Name)) {
            $serviceResults += [PSCustomObject]@{
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                OriginalStatus = [string]$service.Status
                CurrentStatus = [string]$service.Status
                NeedsRemediation = $true
                RemediationAttempted = $false
                RemediationSucceeded = $null
                Notes = "Automatic service is not running."
            }
        }
    }   
    return $serviceResults
}
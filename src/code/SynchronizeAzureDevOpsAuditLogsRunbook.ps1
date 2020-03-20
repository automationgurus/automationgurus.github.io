Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

Function Post-LogAnalyticsData($ustomerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = "timestamp";
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

$LogType = "AzureDevOps"

$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint | Out-Null
Select-AzSubscription -SubscriptionId $Conn.SubscriptionID | Out-Null

$KeyVaultName =  Get-AutomationVariable -Name KeyVaultName
Write-Output -InputObject 'Get keyvault name from automation account variables - success'

$OrganizationName = Get-AutomationVariable -Name OrganizationName
Write-Output -InputObject 'Get Azure DevOps organization name from automation account variables - success'

$CustomerId = Get-AutomationVariable -Name WorkspaceId
Write-Output -InputObject 'Get Log Analytics Workspace Id from automation account variables - success'

$LogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace | Where-Object -Property CustomerId -EQ $CustomerId
$SharedKey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $logAnalyticsWorkspace.ResourceGroupName -Name $logAnalyticsWorkspace.Name).PrimarySharedKey
Write-Output -InputObject "Get shared key directly from '$( $logAnalyticsWorkspace.Name )  - success"

$PersonAccessToken = (Get-AzKeyVaultSecret -VaultName $KeyVaultName  -Name 'AzureDevOpsPersonalAccessToken').SecretValueText 
Write-Output -InputObject "Get Personal Access Token from key vault '$( $KeyVaultName  )' - success"

$StartTime = Get-AutomationVariable -Name LastAzureDevOpsSyncDate
$StartTime = $StartTime.ToUniversalTime().GetDateTimeFormats("o")

[string]$EndTimeQuery = [DateTime]::Now.ToUniversalTime().GetDateTimeFormats("o")

Write-Output -InputObject "Script will look for audi events created between $( $StartTime ) and $( $endTimeQuery )"

$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f 'basic',$PersonAccessToken)))

$Headers = @{
    Authorization = "Basic $Base64AuthInfo"
}

[array]$ApiOutputs = @()
[string]$ContinuationToken = ''

do {
    $EndpointUri = "https://auditservice.dev.azure.com/$( $OrganizationName )/_apis/audit/auditlog?api-version=5.1-preview.1"
    $EndpointUri += "&batchSize=200"
    $EndpointUri += "&skipAggregation=true"
    $EndpointUri += "&startTime=$( $StartTime )"
    $EndpointUri += "&endTime=$( $endTimeQuery )"

    if ($ContinuationToken) {
        $EndpointUri += "&continuationToken=$( $continuationToken )"
    }

    $ApiOutput = Invoke-RestMethod -Uri $endpointUri -Headers $headers  -Method Get 
    $ContinuationToken = $ApiOutput.continuationToken #tu

    $ApiOutputs += $ApiOutput

} while ($ApiOutput.hasMore)

[array]$DecoratedAuditLogEntries = $ApiOutputs.decoratedAuditLogEntries 

if(-not $DecoratedAuditLogEntries) {
    Write-Output -InputObject 'There are no new audit logs.'
    return;
}

Write-Output -InputObject "Found $( $DecoratedAuditLogEntries.Count ) new audit entries"


foreach ($item in $DecoratedAuditLogEntries ) {
    $item.data = $item.data | ConvertTo-Json -Compress -Depth 100
}

$RecordsJson = $DecoratedAuditLogEntries | `
    Select-Object -ExcludeProperty actorImageUrl | `
    ConvertTo-Json 


$StatusCode = Post-LogAnalyticsData -customerId $CustomerId -sharedKey $SharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($recordsJson)) -logType $LogType

if($StatusCode -eq 200){
    Set-AutomationVariable -Name LastAzureDevOpsSyncDate -Value $endTimeQuery
    Write-Output -InputObject 'Azure DevOps audi logs forwarding completed successfully'
}
# Forward Azure DevOps Audit Logs to Log Analaytics Workspace
<!-- ![alt](azure-devops-audit-logs-forwarding-001.jpg) -->

## Why? What will my company achive?

The most important question is always *why*?

1. Have all audit logs in one place
2. Search logs with ease using KQL
3. Collerate with other logs
4. 



## What do I need?

| Resource | Role |
|--|-|
| Key Vault| Store personal access token secret|


## Update only incremental

1. Get value of *Set-AutomationVariable* variable from Azure Automation Account
2. Upload delta to Log Analytics Workspace
3. Update *Set-AutomationVariable* value

## How does it work?

1. Trigger runbook execution by Azure Automation Schedule.
2. Test 
   * Test2

## Prepare infrastructure

1. In your Azure DevOps Organization create Personal Access Token with *read audit log events, manage and delete streams* scope.

2. Create Azure Automation Account with RunAs account.

3. Create Azure Key Vault.

4. Add *get and list secret* permission to *Azure Run As Account*.

5. Create new secret named *AzureDevOpsPersonalAccessToken*. Set PAT as a avalue.



Allow 



# Step by step instruction

## Create personal access token



1. Navigate to your organization

```
https://dev.azure.com/{OrganizationName}/
```

2. 


### Short version

1. Scheduler triggers Powershell runbook.
2. Get

### Detailed version


In Azure portal you can have audit logs.


``` powershell
$LogType = "AzureDevOps"

$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
$AzureContext = Select-AzSubscription -SubscriptionId $Conn.SubscriptionID

$KeyVaultName =  Get-AutomationVariable -Name KeyVaultName
Write-Output -InputObject 'Get keyvault name from automation account variables - success'

$OrganizationName = Get-AutomationVariable -Name OrganizationName
Write-Output -InputObject 'Get Azure DevOps organization name from automation account variables - success'

$CustomerId = Get-AutomationVariable -Name WorkspaceId
Write-Output -InputObject 'Get Log Analytics Workspace Id from automation account variables - success'

$SharedKey = (Get-AzKeyVaultSecret -VaultName $KeyVaultName  -Name 'LogAnalyticsSharedKey').SecretValueText 

<#
$LogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace | Where-Object -Property CustomerId -EQ $CustomerId
$SharedKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $logAnalyticsWorkspace.ResourceGroupName -Name $logAnalyticsWorkspace.Name
Write-Output -InputObject "Get shared key directly from '$( $logAnalyticsWorkspace.Name )  - success"
#>

$PersonAccessToken = (Get-AzKeyVaultSecret -VaultName $KeyVaultName  -Name 'AzureDevOpsPersonalAccessToken').SecretValueText 
Write-Output -InputObject "Get Personal Access Token from key vault '$( $KeyVaultName  )' - success"


$startTime = Get-AutomationVariable -Name LastAzureDevOpsSyncDate
$startTime = $startTime.ToUniversalTime().GetDateTimeFormats("o")


$endTime = [DateTime]::Now.ToUniversalTime()
$endTimeQuery = $endTime.GetDateTimeFormats("o")

Write-Output -InputObject "Script will look for audi events created between $( $startDate ) and $( $endTime )"


$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f 'basic',$PersonAccessToken)))

$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

[array]$apiOutputs = @()
[string]$continuationToken = ''

do {
    $endpointUri = "https://auditservice.dev.azure.com/$( $OrganizationName )/" + 
            "_apis/audit/auditlog?api-version=5.1-preview.1" # + "&skipAggregation=$( $skipAggregation )"
    $endpointUri += "&batchSize=200"
    $endpointUri += "&skipAggregation=true"
    $endpointUri += "&startTime=$( $startTime )"
    $endpointUri += "&endTime=$( $endTime )"

    #detecting first run
    if ($continuationToken) {
        $endpointUri += "&continuationToken=$( $continuationToken )"
    }

    $apiOutput = Invoke-RestMethod -Uri $endpointUri -Headers $headers  -Method Get 
    $continuationToken = $apiOutput.continuationToken #tu

    #$apiOutput.decoratedAuditLogEntries

    $apiOutputs += $apiOutput


} while ($apiOutput.hasMore)

$decoratedAuditLogEntries = $apiOutputs.decoratedAuditLogEntries 

if(-not $decoratedAuditLogEntries) {
    Write-Output -InputObject 'There are no new audit logs.'
    return;
}

Write-Output -InputObject "Found $( $decoratedAuditLogEntries.Count ) new audit entries"


foreach ($item in $decoratedAuditLogEntries ) {
    $item.data = $item.data | ConvertTo-Json -Compress -Depth 100
    #$item.timestamp = $item.timestamp.ToUniversalTime() | Get-Date -Format o
}

$recordsJson = $decoratedAuditLogEntries | `
    Select-Object -ExcludeProperty actorImageUrl | `
    ConvertTo-Json 

Write-Output -InputObject $recordsJson 

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

Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
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

$statusCode = Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($recordsJson)) -logType $logType

Write-Output -InputObject $statusCode

if($statusCode -eq 200){
    Set-AutomationVariable -Name LastAzureDevOpsSyncDate -Value $endTime
}

```

<!-- 
nie da sie z portalu wywnioskowac kto zlecil deployment 
mozna pobrac logi z LAW: json/ csv/ portal i probowac wnioskowac, lub - do praktycznego przykladu sie nada
dwie opcje pobierania shared key - dodanie custom roli / uprawnieni do workspace / utrzymywanie wszystkiego w 

decyzje
KV - rotacja kluczy w KV spowoduje konieczność update w KV - chcemy tego uniknac
ustawienie zmiennej w Azure Automation - ma sens
gdzie trzymac PATa - azureautomation/ kv - historia... + moze tez persystencje/ nigdzie/ 
czy PAT jest potrzebny, bo moze dac dostep do API (full) na SP

gdzie trzymac persystencje - kv - azure automation

customerid - kv 


update date time variable ... :| dlatego string ostatecznie ...


podejscie IaC powoduje, ze z portalu widac tylko SPNa, ktory jest uzywany w ADO.

get last check date
upload delta to log analytics workspace
update date

pierwszy pomysl to bylo wsadzic PATa, i pozostale secrety do KV, ale moznaby wykroic odpowiednia role, ale mam kontrybutora...


nie dzialalo z zaufanych Azure...

-->

# deploy keyvault

## Prepare infrastructure

### Key Vault

### Azure Automation Account




## Our mission

* `mkdocs new [dir-name]` - Create a new project.
* `mkdocs serve` - Start the live-reloading docs server.
* `mkdocs build` - Build the documentation site.
* `mkdocs -h` - Print help message and exit.

```json
{
    "type":2
}
```

# Lets test?

```
AzureDevOps_CL 
| sort by TimeGenerated desc nulls last 
| where actionId_s == "Extension.Installed" 
| project  TimeGenerated, actionId_s, scopeDisplayName_s , details_s, actorDisplayName_s 
```

|TimeGenerated|	actionId_s|	scopeDisplayName_s|	details_s|	actorDisplayName_s|
|-|-|-|-|-|
|2020-03-15T16:47:19.367Z|	Extension.Installed|	AutomationGuyIO (Organization)|	Extension "Secure DevOps Kit (AzSK) CICD Extensions for Azure" from publisher "Microsoft DevLabs" was installed - Version "3.1.7"|	Kamil Więcek


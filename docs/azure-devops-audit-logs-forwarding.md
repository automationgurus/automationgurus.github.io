# Forward Azure DevOps Audit Logs to Log Analytics Workspace

We developed an automated solution that is continuously streaming audit logs from Azure DevOps to Log Analytics Workspace.


![Stream audit logs from Azure DevOps to Log Analytics Workspace](img/azure-devops-audit-logs-forwarding-004.jpg)

## Why should you read this article? What are the benefits?

1. You don't want to browse logs though Azure DevOps web manually.
1. You don't want to export audit logs to CSV and analyze them in Excel.
1. You want to have **all audit logs in the same place**. It sounds like your regulator, doesn't it?
1. You'll be able to **search effectively** across logs, using Kusto Query Language.
1. You want to **keep** audit logs for more than 90 days.
1. You'll easily bind ADO events to other events from another part of your environment.
1. You'll Grab details about activities like permissions changes, deleted resources, branch policy changes.
1. If you're **IaC enthusiastic**, then the majority of you work in ADO. It's worth to capture events from there.

![Stream audit logs from Azure DevOps to Log Analytics Workspace](img/azure-devops-audit-logs-forwarding-002.jpg)

## What is available out of the box?

<!-- ![Stream audit logs from Azure DevOps to Log Analytics Workspace](img/azure-devops-audit-logs-forwarding-005.jpg) -->

- Browsing logs through web portal.
- Exporting them to JSON/ CSV
- Analyze them using Excel/ custom tools.

More general information about Azure DevOps Auditing is available in the link below. It's not our purpose to paraphrase MS documentation. 
Please read the following part of their documentation to get more details about ADO auditing in general.

[You can find more details here!](https://docs.microsoft.com/en-us/azure/devops/organizations/settings/azure-devops-auditing?view=azure-devops&tabs=preview-page)

## Acronyms and abbreviations 

- **ADO** - Azure DevOps
- **ORG** - Azure DevOps Organization
- **PAT** - Personal Access Token from ADO

- **AAA** - Azure Automation Account
- **ARA** - Azure Run As Account

- **AKV** - Azure Key Vault

- **LAW** - Azure Log Analytics Workspace


## Who are you?

We assume that...

```text
PS C:\> $You.SessionLevelReadiness -GE 200
True
```

... so we're not providing detailed, step by step instructions on how to create every single resource required to deploy this solution.
We believe that you can deploy and configure them without additional instructions, or you're able to find them on your own.

## Prepare infrastructure 

Here are required resources and it's the configuration required to deploy the described solution:

- Organization in Azure DevOps with enabled auditing.
- Personal Access Token with *read audit log events, manage and delete streams* scope.
- Azure Automation Account with *Azure Run As Account*. 
- AAA string variables named KeyVaultName, WorkspaceId, OrganizationName
- AAA string variable named LastAzureDevOpsSyncDate with round-trip date/time pattern value (for example *2020-01-01T00:00:00.0000001Z*)
- Azure Key Vault
- AKV *Get and list secret* access policy for ARA.
- *AzureDevOpsPersonalAccessToken* secret in AKV containing PAT value.
- Azure Log Analytics Workspace.
- *Shared key read* permissions for ARA.
- Azure Automation Powershell Runbook.

## Solution overview. More details.

1. Every single hour Azure Automation Runbook (AAC) is invoked by schedule.
2. Set context. All actions are performed in the context of *Azure Run As Account*. This account was created during Automation Account creation.
3. Get parameters (read details above).
4. Get all ADO audit logs entries between *LastAzureDevOpsSyncDate* and current date and time.
5. Upload event to Log Analytics Workspace via REST API call.
6. Update *LastAzureDevOpsSyncDate*.


## Solution parameters

| Script Parameter   | Source/ Where you should set it |
|--------------------|-|
| $KeyVaultName      | KeyVaultName variable from Automation Account |
| $StartTime         | LastAzureDevOpsSyncDate variable from Automation Account | 
| $OrganizationName  | OrganizationName variable from Automation Account |
| $CustomerId        | WorkspaceId variable from Automation Account |
| $PersonAccessToken | AzureDevOpsPersonalAccessToken secret from  Azure KeyVault |
| $SharedKey         | SharedKey property from Log Analytics Workspace (Id = $CustomerId) |


## Powershell Runbook

We use Build-Signature and Post-LogAnalyticsData from 
[MS DOCS: Data collector api](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-collector-api)
. In this example, they use $TimeStampField variable that is global. It isn't good practice to use in function variables defined out of function scope. We replaced this behavior.

You can find the script we use here: TBD

Some more description about actions inside the script

Get variables from Azure Automation:

```powershell
$OrganizationName = Get-AutomationVariable -Name OrganizationName
```

Get LAW SharedKey (it's required to invoke API calls)

```powershell
$SharedKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $logAnalyticsWorkspace.ResourceGroupName -Name $logAnalyticsWorkspace.Name
```

```powershell
$endpointUri = "https://auditservice.dev.azure.com/$( $OrganizationName )/" + 
        "_apis/audit/auditlog?api-version=5.1-preview.1" # + "&skipAggregation=$( $skipAggregation )"
$endpointUri += "&batchSize=200"
$endpointUri += "&skipAggregation=true"
$endpointUri += "&startTime=$( $StartTime )"
$endpointUri += "&endTime=$( $endTime )"

```


###



## It's time to rest and check what we did

![Stream audit logs from Azure DevOps to Log Analytics Workspace](img/azure-devops-audit-logs-forwarding-001.jpg)

```
AzureDevOps_CL 
| sort by TimeGenerated desc nulls last 
| where actionId_s == "Extension.Installed" 
| project  TimeGenerated, actionId_s, scopeDisplayName_s , details_s, actorDisplayName_s 
```

|TimeGenerated| actionId_s|     scopeDisplayName_s|     details_s|      actorDisplayName_s|
|-|-|-|-|-|
|2020-03-15T16:47:19.367Z|      Extension.Installed|    AutomationGuyIO (Organization)| Extension "Secure DevOps Kit (AzSK) CICD Extensions for Azure" from publisher "Microsoft DevLabs" was installed - Version "3.1.7"|      Kamil Więcek

## Solution development insights

- ARA becomes a Contributor by default. Consider changing that.
- Storing LAW SharedKey in AKV is one of the options, but it'll force you to update it on change. We decided to get it directly during the script execution. 
- We could use AAA encrypted value to store PAT, but in case of storing secrets, AKV should always be the primary choice. Other parameters we don't consider as secrets, so we store them in AAA variables.
- Enabling *Allow trusted Microsoft services to bypass this firewall* in AKW Networking configuration didn't allow access from AAA. Therefore we set this setting to *Allow access from all networks*.
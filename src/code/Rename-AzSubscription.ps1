param (
    [string]
    $SubscriptionName,

    [string]
    $NewSubscriptionName
)

$context = Get-AzContext
$azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile;
$rmProfileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile);
$token = $rmProfileClient.AcquireAccessToken($context.Subscription.TenantId).AccessToken;

$subscription = Get-AzSubscription -SubscriptionName $SubscriptionName

$Uri = "https://management.azure.com/subscriptions/$( $subscription.Id )/providers/Microsoft.Subscription/rename?api-version=2019-03-01-preview"

$Body = @{ 
    subscriptionName = $NewSubscriptionName
} | ConvertTo-Json

$headers = @{
    'Host' = 'management.azure.com'
    'Content-Type' = 'application/json';
    'Authorization' = "Bearer $token";
}

$result = Invoke-RestMethod -Uri $Uri -Body $Body -Headers $headers -Method Post

$subscription = Get-AzSubscription -SubscriptionName $SubscriptionName

while ($subscription.Name -eq $NewSubscriptionName) {
    Start-Sleep -Seconds 10
    $subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
}

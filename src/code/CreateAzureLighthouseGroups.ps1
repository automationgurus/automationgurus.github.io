param(
    $TenantID,
    $CustomerName
)

Connect-AzAccount -Tenant $TenantID

$groups = @(
    "Logs-Reader", 
    "Customer-Reader", 
    "Customer-Contributor"
)

foreach ($group in $groups) {
    $groupName = "Lighthouse-$CustomerName-$group"
    $aadGroup = Get-AzADGroup -DisplayName $groupName

    if ($aadGroup) {
        Write-Output "Group $groupName already exists."
    }
    else {
        Try {
            New-AzADGroup -DisplayName $groupName -MailNickname $groupName
            Start-Sleep -s 5
            $aadGroup = (Get-AzADGroup -DisplayName $groupName).ObjectId
            Write-Output "AAD Group $groupName with id $aadGroupId created with success"
        }
        Catch {
            Write-Output "Unexpected error occured during AAD group creation. Error: $($_.exception.Message)"
        }
        
    }
  
}
param(
    $sourceSqlUser,
    $sourceSubscriptionID,
    $sourceSqlServerResourceGroup,
    $sourceSqlServerName,
    $sourceSqlDatabaseName,
    $destinationDatabaseEdition,
    $destinationServiceObjectiveName,
    $destinationDatabaseMaxSizeBytes,
    $destinationSqlUser,
    $destinationSubscriptionID,
    $destinationSqlServerResourceGroup,
    $destinationSqlServerName,
    $destinationSqlDatabaseName,
    $commonSubscriptionId,
    $storageAccountName,
    $storageAccountResourceGroup,
    $keyVaultName,
    $sqlServerSourceKeyVaultEntry,
    $sqlServerDestinationKeyVaultEntry,
    $tenantId
)

Connect-AzAccount -TenantId $tenantId

Select-AzSubscription -SubscriptionId $commonSubscriptionID | Out-Null
$blobUrl = (Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroup -Name $storageAccountName | Select-Object *).Context.BlobEndpoint
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccountResourceGroup -Name $storageAccountName)[0].Value
$sourceSqlServerPassword = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $sqlServerSourceKeyVaultEntry).SecretValue
$destinationSqlServerPassword = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $sqlServerDestinationKeyVaultEntry).SecretValue


Select-AzSubscription -SubscriptionId $sourceSubscriptionID | Out-Null
Try {
    Get-AzSqlDatabase -DatabaseName $sourceSqlDatabaseName -ServerName $sourceSqlServerName -ResourceGroupName $sourceSqlServerResourceGroup
    Write-Output "Found $sourceSqlDatabaseName database on SQL Server $sourceSqlServerName"
}
Catch {
    Write-Output "Database $sourceSqlDatabaseName can not be found on SQL Server $sourceSqlServerName"
    exit
}

$date = Get-Date -Format yyyyMMdd
$url = $blobUrl + "bacpacs/$sourceSqlDatabaseName_$date.bacpac"

$exportRequest = New-AzSqlDatabaseExport -DatabaseName $sourceSqlDatabaseName -ResourceGroupName $sourceSqlServerResourceGroup -ServerName $sourceSqlServerName -StorageKeyType "StorageAccessKey" -StorageUri $url -StorageKey $shdStorageAccountKey -AdministratorLogin $sourceSqlUser -AdministratorLoginPassword $sourceSqlServerPassword
$exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
Write-Output "Exporting database $sourceSqlDatabaseName to bacpac file"
while ($exportStatus.Status -eq "InProgress") {
    Start-Sleep -s 10
    $exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $exportRequest.OperationStatusLink
    Write-Output "Exporting..."
}

Write-Output "Proceeding with destination database..."
Select-AzSubscription -SubscriptionId $destinationSubscriptionID | Out-Null
        
if ($exportStatus.Status -eq "Succeeded") {
    Write-Output "Database $sourceSqlDatabaseName export to bacpac file finished with success."
    $targetDatabase = Get-AzSqlDatabase -DatabaseName $destinationSqlDatabaseName -ResourceGroupName $destinationSqlServerResourceGroup -ServerName $destinationSqlServerName
    if ($targetDatabase) {
        Try {
            Write-Output "Removing database $destinationSqlDatabaseName on target server as it already exist."
            Remove-AzSqlDatabase -DatabaseName $destinationSqlDatabaseName -ResourceGroupName $destinationSqlServerResourceGroup -ServerName $destinationSqlServerName
            Write-Output "Database $destinationSqlDatabaseName removal finished with success"
        }
        Catch {
            Write-Output "Unexpected error occured during removal of database $destinationSqlDatabaseName from server $destinationSqlServerName . Error: $($_.Exception.Message)"
        }
    }

    $importRequest = New-AzSqlDatabaseImport -DatabaseName $destinationSqlDatabaseName -ResourceGroupName $destinationSqlServerResourceGroup-ServerName $destinationSqlServerName -StorageKeyType "StorageAccessKey" -StorageUri $url -StorageKey $storageAccountKey -AdministratorLogin $destinationSqlUser -AdministratorLoginPassword $destinationSqlServerPassword -Edition $destinationDatabaseEdition -ServiceObjectiveName $destinationServiceObjectiveName -DatabaseMaxSizeBytes $destinationDatabaseMaxSizeBytes
    $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
    Write-Output "Importing database $destinationSqlDatabaseName from bacpac file"
    while ($importStatus.Status -eq "InProgress") {
        Start-Sleep -s 10
        $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
        Write-Output "Importing..."
    }
    if ($importStatus.Status -eq "Succeeded") {
        Write-Output "Database $destinationSqlDatabaseName import finished with success."
    }
    else {
        Write-Output "Import of database $destinationSqlDatabaseName to SQL server $destinationSqlServerName failed. Error: $($importStatus.StatusMessage)"
    }
}
else {
    Write-Output "Export of database $destinationSqlDatabaseName from SQL server $destinationSqlServerName failed. Error: $($exportStatus.StatusMessage)"
}
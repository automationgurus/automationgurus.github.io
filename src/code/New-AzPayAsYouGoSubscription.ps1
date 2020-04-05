param (
    $Credentials
)

Write-Host -Object "Start"

$Url = "https://account.azure.com/signup?showCatalog=True&appId=Ibiza_SubscriptionsOverviewBladeCommandBar" 
$Driver = Start-SeChrome
Enter-SeUrl -Driver $Driver -Url $Url

#Enter username

$UsernameElementName = 'loginfmt'
$UsernameElement = Find-SeElement -Driver $Driver -Name $UsernameElementName

while (-not $UsernameElement ) {
    Write-Host -Object "Waiting for element $( $UsernameElementName )"
    Start-Sleep -Seconds 1
    $UsernameElement = Find-SeElement -Driver $Driver -Name $UsernameElementName
}

Send-SeKeys -Element $UsernameElement -Keys $Credentials.UserName

(Find-SeElement -Driver $Driver -Id 'idSIButton9').Click()

#Select 'Personal Account'

$PersonalAccountElement = Find-SeElement -Driver $Driver -Id 'msaTile'
while (-not $PersonalAccountElement ) {
    Start-Sleep -Seconds 1
    $PersonalAccountElement = Find-SeElement -Driver $Driver -Id 'msaTile'
}

$PersonalAccountElement.Click()

#Enter password

$PasswordElementName = 'passwd'
$PasswordElement = Find-SeElement -Driver $Driver -Name $PasswordElementName 

while (-not $PasswordElement ) {
    Write-Host -Object "Waiting for element name $( $PasswordElementName  )"
    Start-Sleep -Seconds 1
    $PasswordElement = Find-SeElement -Driver $Driver -Name $PasswordElementName 
}

Send-SeKeys -Element $PasswordElement -Keys $Credentials.GetNetworkCredential().Password

(Find-SeElement -Driver $Driver -Id 'idSIButton9').Click()

#Select PAYG Plan

$PaygPlanElementClassName = 'plan_type_consumption'
$PaygPlanElement = Find-SeElement -Driver $Driver -ClassName $PaygPlanElementClassName |
    Where-Object -Property Text -like '*Pay-As-You-Go*'

while (-not $PaygPlanElement) {
    Write-Host -Object "Waiting for element class $( $PaygPlanElementClassName  )"
    Start-Sleep -Seconds 1
    $PaygPlanElement = Find-SeElement -Driver $Driver -ClassName $PaygPlanElementClassName |
        Where-Object -Property Text -like '*Pay-As-You-Go*'
}

$PaygPlanElement.Click() 

#Set Payment and support agreement

$ElementsToClick = @('card-submit-button', 'no-support-option', 'attach-support-button')
foreach ($elementId in $ElementsToClick ) {
    do {
        $Element = Find-SeElement -Driver $Driver -Id $elementId

        if ($Element){
            try {
                $Element.Click()
            }
            catch {
                $Element = $null
            }
        }
        else {
            Write-Host -Object "Waiting for element id $( $elementId )"
            Start-Sleep -Seconds 1
        }
    }
    while (-not $Element)
}

#Accept terms

$AgreeElementId = 'accept-terms-checkbox'
$AgreeElement = Find-SeElement -Driver $Driver -Id $AgreeElementId 

while (-not $AgreeElement) {
    Write-Host -Object "Waiting for element id $( $AgreeElementId  )"
    Start-Sleep -Seconds 1
    $AgreeElement = Find-SeElement -Driver $Driver -Id $AgreeElementId 
}

Send-SeKeys -Element $AgreeElement -Keys ' '

#Create subscription

$AcceptElementId = 'accept-terms-submit-button'

do {
    $AcceptElement = Find-SeElement -Driver $Driver -Id $AcceptElementId 

    if ($AcceptElement){
        try {
            $AcceptElement.Click()
        }
        catch {
            $AcceptElement = $null
        }
    }
    else {
        Write-Host -Object "Waiting for element id $( $AcceptElementId  )"
        Start-Sleep -Seconds 1
    }
}
while (-not $AcceptElement )

Write-Host -Object "End"

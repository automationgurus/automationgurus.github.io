

$Exceptions = @(
    'src',
    '.gitignore',
    # 'CNAME',
    'Clean-Root.ps1'
    'Publish-Docs.ps1'
    # 'site'
)

Get-ChildItem `
    | Where-Object -Property Name -NotIn $Exceptions `
    | Remove-Item -Force -Recurse -Confirm:$false

Set-Location -Path .\src\

Out-File -Append -FilePath .\mkdocs.yml -InputObject "google_analytics: ['UA-160963982-1', 'auto']" 
# Add-Content -Value "# google_analytics: ['UA-160963982-1', 'auto']" 

mkdocs build -d ..\site\ -c
cd ..

Copy-Item  -Path .\site\* -Recurse -Force 
Remove-Item .\site -Recurse -Force

# Set-Location -Path ..
# copy-ite
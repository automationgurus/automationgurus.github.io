$Exceptions = @(
    'src',
    '.gitignore',
    'CNAME',
    'Clean-Root.ps1'
    'site'
)

Get-ChildItem `
    | Where-Object -Property Name -NotIn $Exceptions `
    | Remove-Item -Force -Recurse -Confirm:$false

Set-Location -Path .\src\

mkdocs build -d ..\site\ -c

# Set-Location -Path ..
# copy-ite
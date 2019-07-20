[CmdletBinding()]
Param(
    [Parameter()]
    [string]
    $ModuleName = 'sjAzureTools',

    [Parameter()]
    [hashtable]
    $Dependencies = @{
        PackageManagement = '1.3.1'
        PowerShellGet     = '2.1.2'
        InvokeBuild       = '5.5.2'
    },

    [Parameter()]
    [ValidateSet('Init', 'Clean', 'Build', 'Test', 'Deploy')]
    [string[]]
    $Task,

    [Parameter()]
    [object]
    $File,

    [Parameter()]
    [switch]
    $Safe,

    [Parameter()]
    [switch]
    $Summary
)

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Verbose:$false
$PSDefaultParameterValues = @{
    '*-Module:Verbose'                  = $false
    '*-Module:Force'                    = $true
    'Import-Module:ErrorAction'         = 'Stop'
    'Install-Module:AcceptLicense'      = $true
    'Install-Module:AllowClobber'       = $true
    'Install-Module:Confirm'            = $false
    'Install-Module:ErrorAction'        = 'Stop'
    'Install-Module:Repository'         = 'PSGallery'
    'Install-Module:Scope'              = 'CurrentUser'
    'Install-Module:SkipPublisherCheck' = $true
}
Write-Host "Resolving module dependencies"
foreach ($dependency in $Dependencies.Keys) {
    $parameters = @{
        Name           = $dependency
        MinimumVersion = $Dependencies[$dependency]
    }
    Write-Host "[$dependency] Resolving"
    try {
        if ($imported = Get-Module $dependency) {
            Write-Host "[$dependency] Removing imported module"
            $imported | Remove-Module
        }
        Import-Module @parameters
    }
    catch {
        Write-Host "[$dependency] Installing missing module"
        Install-Module @parameters
        Import-Module @parameters
    }
}

Write-Host "Executing Invoke-Build"
Invoke-Build -ModuleName $ModuleName @PSBoundParameters
Param (
    [String]
    $ModuleName = 'sjAzureTools',

    $targetModuleVerDir
)

task . Init, Clean, Build, Test

task Init {
    Write-Host "Build System Details:"
    Write-Host "Engine  : PowerShell $($PSVersionTable.PSVersion.ToString())"
    Write-Host "Host OS : $(if($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows){"Windows"}elseif($IsLinux){"Linux"}elseif($IsMacOS){"macOS"}else{"[UNKNOWN]"})"
    Write-Host "PWD     : $PWD"
    Write-Host "$((Get-ChildItem Env: | Where-Object {$_.Name -match "^(BUILD_|SYSTEM_|BH)"} | Sort-Object Name | Format-Table Name,Value -AutoSize | Out-String).Trim())"
    'Pester' | Foreach-Object {
        try {
            Import-Module $_ -ErrorAction Stop
        }
        catch {
            Install-Module -Name $_ -Repository PSGallery -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Confirm:$false -ErrorAction Stop -Force
            Import-Module -Name $_ -Verbose:$false -ErrorAction Stop -Force
        }
    }
    $moduleDir = Join-Path '.' $ModuleName
    $manifest = Import-PowerShellDataFile (Join-Path $moduleDir "$($ModuleName).psd1")
    $BuildOutputFolder = Join-Path '.' 'BuildOutput'
    $targetModuleDir = Join-Path $BuildOutputFolder $ModuleName
    $originalVersion = $manifest.ModuleVersion.ToString()
    $nextVersionSplit = $originalVersion.Split('.')
    $lastVersionBumped = [int]$nextVersionSplit[-1] + 1
    $nextVersion = "{0}.{1}.{2}" -f $nextVersionSplit[0], $nextVersionSplit[1], $lastVersionBumped
    $script:targetModuleVerDir = Join-Path $targetModuleDir $nextVersion
}

task Clean Init, {
    remove BuildOutput
}

task Build {
    $moduleDir = Join-Path '.' $ModuleName
    $manifest = Import-PowerShellDataFile (Join-Path $moduleDir "$($ModuleName).psd1")
    $BuildOutputFolder = Join-Path '.' 'BuildOutput'
    $targetModuleDir = Join-Path $BuildOutputFolder $ModuleName
    $originalVersion = $manifest.ModuleVersion.ToString()
    $nextVersion = $targetModuleVerDir -split [regex]::Escape([system.io.path]::DirectorySeparatorChar)
    Update-ModuleManifest -Path (Join-Path $moduleDir "$($ModuleName).psd1") -ModuleVersion $nextVersion[-1]
    $targetPSM1File = Join-Path $targetModuleVerDir "$($ModuleName).psm1"

    # Create the BuildOutput/Module/Version folder
    New-Item -Path $targetModuleVerDir -ItemType Directory -Force

    # Create a blank PSM1 file in $targetModuleVerDir
    New-Item -Path $targetPSM1File -ItemType File -Force

    # Copy our private and public functions to the new PSM1 file
    foreach ($scope in @('Private', 'Public')) {
        Get-ChildItem (Join-Path $moduleDir $scope) -Filter "*.ps1" | ForEach-Object {
            Get-Content $_.FullName | Add-Content $targetPSM1File
        }
    }

    # Paste our Export-ModuleMember string to the bottom of the new PSM1 file

    'Export-ModuleMember -Function *-*' | Add-Content $targetPSM1File

    # Copy our PSD1 from the $moduleDir to $targetModuleVerDir
    Copy-Item -Path (Join-Path $moduleDir "$($ModuleName).psd1") -Destination $targetModuleVerDir -Force

    # Reset our source version
    Update-ModuleManifest -Path (Join-Path $moduleDir "$($ModuleName).psd1") -ModuleVersion $originalVersion

    # Profit?
}

task Test {
    Invoke-Pester -OutputFormat NUnitXml -OutputFile ".\BuildOutput\TestResults$(Get-Date -Format yyyyMMddHHmmss).xml" -PassThru
}

task Deploy Init, {
    "Publishing version to PSGallery from path $targetModuleVerDir"
    Publish-Module -Path $targetModuleVerDir -NuGetApiKey $env:NugetApiKey -Repository PSGallery -Verbose
    "Deployment successful!"
}
$ModuleManifestName = 'sjAzureTools.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\sjAzureTools\$ModuleManifestName"

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
}


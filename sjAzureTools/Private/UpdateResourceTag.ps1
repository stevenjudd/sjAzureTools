function updateResourceTag {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource]$ResourceObject,
        
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]$Tags
    )

    Write-Verbose "Get the existing tags from the Resource"
    try {
        $ResourceTags = $ResourceObject.Tags
        if (-not($ResourceTags)) {
            Write-Verbose "No tags exist. Set ResourceTags variable as empty array"
            $ResourceTags = @{ }
        }
        else {
            if ($ResourceTags.Count + $Tags.Count -gt 15) {
                Write-Error "The number of tags for $($ResourceObject.Name) is greater than 15"
                Return
            }
        }
    }
    catch {
        $pscmdlet.ThrowTerminatingError($_)
    }

    #add new tags to the array
    foreach ($key in $Tags.keys) {
        $ResourceTags[$key] = $Tags[$key]
    }
    
    try {
        Write-Verbose "Setting tags on ResourceID: $($ResourceObject.ResourceId)"
        Set-AzResource -Tag $ResourceTags -ResourceId $ResourceObject.ResourceId -Force -ErrorAction Stop
        Write-Verbose "Updated Tags on $($ResourceObject.Name)"
    }
    catch {
        $pscmdlet.ThrowTerminatingError($_)
    }
} #end function updateResourceTag

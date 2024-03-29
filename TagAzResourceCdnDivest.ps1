function TagAzResourceDivest {

    #Requires -Version 3.0
    # Requires -Modules Az #don't require Az module, it takes a LONG time to resolve this requirement

    <#
    .NOTES
        PowerShell function written to add tags to Azure Resource Groups
        Written by Steven Judd on 2019/06/25
        Version 20190710
        Updated by Steven Judd on 2019/07/08 to do the following:
            Removed the UpdatedBy parameter and made it a variable in the begin block
            Added UpdatedBy tag as an automatically updated variable

        Add Features:
            Need to check the number of tags and not add more than 15 (Azure limit)
            
    .SYNOPSIS
        Add Divest tags to an Azure Resource.
    .DESCRIPTION
        This function will add tags to an Azure Resource. It will not remove any
        existing tags. Rather it will add those that need to be added and update tags 
        that already exist with new data if it is provided.

    .LINK
        XXXX
    .PARAMETER ResourceID
        Enter the Azure ResourceID for the Resource to be tagged. The benefit of using
        the ResourceID is the Subscription and Resource Group information is not 
        required to be known or entered.

        This is the default parameter and will be required if no parameters are entered.
    .PARAMETER SubscriptionName
        Enter the SubscriptionName for the Resource to be tagged.
    .PARAMETER ResourceGroupName
        Enter the Resource Group Name for the Resource to be tagged.
    .PARAMETER Name
        Enter the Name for the Resource to be tagged.
    .EXAMPLE
        TagAzResourceDivest -SubscriptionName NotFree -ResourceGroupName VMs -Name Server1

        This example will tag the Server1 resource in the VMs resource group in
        the NotFree subscription with the Divest:Yes and 
        UpdatedBy:[username] tags
    .EXAMPLE
        TagAzResourceDivest -ResourceID (Get-AzResource Server1).ResourceID

        This example will add the Divest:Yes tag on the Server1 Resource in the current
        subscription. It will also put the current username value in the UpdatedBy tag.

        Note: Make sure the Get-AzResource command returns the proper object.
    .EXAMPLE
        Get-AzResource Server1 | TagAzResourceDivest

        This example will add the Divest:Yes tag on the Server1 Resource in the current
        subscription. It will also put the current username value in the UpdatedBy tag.
        This method shows that you can pipe an object to the TagAzResourceDivest 
        function and it will tag the resource.

        Note: Make sure the Get-AzResource command returns the proper object.
    .EXAMPLE
        Get-Content "C:\temp\ServersToTag.csv"

        Name,SubscriptionName,ResourceGroupName
        azumsapsd011p,NotFree,RG_CGYESRI
        azumsapsd012p,NotFree,RG_CGYESRI
        azumsapsd013p,NotFree,RG_CGYESRI
        azumsapsd014p,NotFree,RG_CGYESRI

        Import-Csv "C:\temp\ServersToTag.csv" | TagAzResourceDivest -Verbose -OutVariable updatedAzResources

        This example uses a CSV file with the Resource Names, Subs, and RGs and pipes the
        contents to the TagAzResourceDivest function. It will return Verbose output as
        well as put the output into the $updatedAzResources variable to make it easy to
        review the results of the function.
    #>

    [cmdletbinding(DefaultParameterSetName = "ResourceID")]

    param(
        [Parameter(Position = 0, Mandatory, ParameterSetName = "ResourceID",
            ValueFromPipelineByPropertyName)]
        [string]$ResourceID,
        
        [Parameter(Position = 0, Mandatory, ParameterSetName = "SubRgName",
            ValueFromPipelineByPropertyName)]
        [string]$SubscriptionName,

        [Parameter(Position = 1, Mandatory, ParameterSetName = "SubRgName",
            ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName,

        [Parameter(Position = 2, Mandatory, ParameterSetName = "SubRgName",
            ValueFromPipelineByPropertyName)]
        [string]$Name

        # Placeholder for adding the ability to pass a PSResource object
        # [Parameter(Position=0,Mandatory,ParameterSetName="InputObject",
        #     ValueFromPipeline)]
        #     [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource]$InputObject,
 
        #the tags variable needs to take a hashtable
        # [Parameter(Position=3,
        #            ValueFromPipelineByPropertyName)]
        #     [System.Collections.Hashtable]$Tags
    )

    begin {
        #region Load custom functions

        function updateResourceTag {
            param([Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource]$ResourceObject)

            Write-Verbose "Get the existing tags from the Resource"
            try {
                $ResourceTags = $ResourceObject.Tags
                if (-not($ResourceTags)) {
                    Write-Verbose "No tags exist. Set ResourceTags variable as empty array"
                    $ResourceTags = @{ }
                }
            }
            catch {
                $pscmdlet.ThrowTerminatingError($_)
            }

            #add new tags to the array
            #needs to pull tags from the $tags variable
            $ResourceTags['Divest'] = "Yes"
            $ResourceTags['UpdatedBy'] = $UpdatedBy
            
            try {
                Write-Verbose "Setting tags on ResourceID: $($ResourceObject.ResourceId)"
                Set-AzResource -Tag $ResourceTags -ResourceId $ResourceObject.ResourceId -Force -ErrorAction Stop
                Write-Verbose "Updated Tags on $($ResourceObject.Name)"
            }
            catch {
                $pscmdlet.ThrowTerminatingError($_)
            }
        } #end function updateResourceTag

        #endregion

        #region check to see if connected to Azure and if not initiate a connection
        try {
            Write-Verbose "Checking connection to Azure Resource Manager"
            $AzureContext = Get-AzContext -ErrorAction Stop
            #if not connected the Id will be $null
            if (-not($AzureContext.Account.Id)) { 
                $pscmdlet.ThrowTerminatingError("Run Add-AzAccount to login to Azure") #this will move to the Catch block instead of throwing the error message
            }
        }
        catch {
            try {
                Write-Verbose "CONNECTING connection to Azure Resource Manager"
                if ($SubscriptionName) {
                    $null = Add-AzAccount -Subscription $SubscriptionName -ErrorAction Stop
                }
                else {
                    $null = Add-AzAccount -ErrorAction Stop
                }
                $AzureContext = Get-AzContext -ErrorAction Stop
            }
            catch {
                $pscmdlet.throwTerminatingError($_)
            }
        }
        Write-Verbose "Azure Context: $($AzureContext.Tenant.Id)"
        #endregion

        #get initial subscription to return to at the end of the function
        $InitialSubscription = Get-AzContext
        Write-Verbose "Initial subscription set to $((Get-AzSubscription | Where-Object SubscriptionId -eq $InitialSubscription.Subscription).Name)"

        #set UpdatedBy
        $UpdatedBy = [Environment]::UserName
    } #end begin block

    process {
        #get the Subscription from the ResourceId
        if ($ResourceID) {
            $SubscriptionName = (Get-AzSubscription -SubscriptionId ((Get-AzResource -ResourceId $ResourceID).ResourceId -split '/')[2]).Name
        }

        #set the subscription
        Write-Verbose "Set the subscription to '$SubscriptionName'"
        try {
            $null = Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop
        }
        catch {
            $pscmdlet.ThrowTerminatingError($_)
        }

        if ($ResourceGroupName) {
            Write-Verbose "Check to ensure the Resource Group exists"
            try {
                $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
                #the below check may not be necessary based on how Get-AzResourceGroup handles not finding the specified RG
                if (-not($ResourceGroup)) {
                    $pscmdlet.ThrowTerminatingError("Unable to find specified Resource Group: $ResourceGroup")
                }
            }
            catch {
                Write-Error "Unable to find the specified Resource Group '$ResourceGroupName' in the '$SubscriptionName' Subscription"
                Continue
            }
        } #end if $ResourceGroupName

        #get Resource object
        if ($ResourceID) {
            try {
                $ResourceObject = Get-AzResource -ResourceId $ResourceID
            }
            catch {
                Write-Error $_
                continue 
            }
        } #end if not $ResourceID
        else {
            try {
                $ResourceObject = Get-AzResource -Name $Name -ResourceGroupName $ResourceGroupName
            }
            catch {
                Write-Error $_
                continue 
            }
        }
        
        updateResourceTag -ResourceObject $ResourceObject

        #if resource is a VM, get and tag the Disks and NICs
        if ($ResourceObject.Type -eq "Microsoft.Compute/virtualMachines") {
            Write-Verbose "Object is a VM. Tagging the disks and NICs"
            Write-Verbose "Getting the VM object"
            $vmObject = Get-AzVm -ResourceGroupName $ResourceObject.ResourceGroupName -Name $ResourceObject.ResourceName

            Write-Verbose "Getting OS disk ResourceObject and tagging it"
            $osDiskObject = Get-AzResource -Name $vmObject.StorageProfile.OsDisk.Name -ResourceGroupName $vmObject.ResourceGroupName
            updateResourceTag -ResourceObject $osDiskObject

            Write-Verbose "Getting Data disks ResourceObject and tagging them"
            foreach ($dataDisk in $vmObject.StorageProfile.DataDisks) {
                $dataDiskObject = Get-AzResource -Name $dataDisk.Name -ResourceGroupName $vmObject.ResourceGroupName
                updateResourceTag -ResourceObject $dataDiskObject
            }
            Write-Verbose "Getting NICs ResourceObject and tagging them"
            foreach ($nic in $vmObject.NetworkProfile.NetworkInterfaces) {
                $nicObject = Get-AzResource -ResourceId $nic.Id
                updateResourceTag -ResourceObject $nicObject
            }
        }

    } #end process block

    end {
        if ((Get-AzContext).TenantId -ne $InitialSubscription.TenantId) {
            Write-Verbose "Return to initial subscription: $((Get-AzSubscription | Where-Object SubscriptionId -eq $InitialSubscription.Subscription).Name)"
            $null = Set-AzContext -Subscription ($InitialSubscription.Subscription)
        } #end if not in Initial Subscription
    }
    
} #end TagAzResourceDivest function

#test runs
#TagAzResourceDivest -SubscriptionName NotFree -ResourceGroupName VMs -Name Server1
#TagAzResourceDivest -ResourceID '/subscriptions/8a5f240d-3141-4a50-936b-81999ba32d01/resourceGroups/VMs/providers/Microsoft.Compute/virtualMachines/Server1'
#TagAzResourceDivest -ResourceID (Get-AzResource -Name Server1).ResourceID -Verbose
#Get-AzResource -Name Server1 | TagAzResourceDivest

#Get-AzResource -Name Server1 | Export-Clixml -path $env:temp\azresourcedata.xml
#$serverstoupdate = Import-Clixml -Path $env:temp\azresourcedata.xml
#$serverstoupdate | TagAzResourceDivest -Verbose

#Import-Csv C:\temp\ServerList.csv | select -first 2 -Skip 1 | % {if(-not(Get-AzResource -Name $_.server -TagName Divest -TagValue Yes)){Get-AzResource -Name $_.server}} | TagAzResourceDivest -Verbose
#Import-Csv C:\temp\ServerListWithSubRgInfo.csv | select -first 2 -Skip 4 | TagAzResourceDivest -Verbose
#Import-Csv "C:\temp\ServersToTag.csv" | TagAzResourceDivest -Verbose
variable resource_group_name {
    description = "Resource Group Name"
    default   = "azure-speed-test-blobs-qliu"
    type    = string
}
variable resource_group_location {
    description = "Resource Group Location"
    default     = "eastasia"
    type        = string
}

variable locations { #az account list-locations
    description = "Locations"
    # default     = [australiacentral,australiacentral2,australiaeast,australiasoutheast,brazilsouth,brazilsoutheast,brazilus,canadacentral,canadaeast,centralindia,centralus,centraluseuap,eastasia,eastus,eastus2,eastus2euap,francecentral,francesouth,germanynorth,germanywestcentral,japaneast,japanwest,jioindiacentral,jioindiawest,koreacentral,koreasouth,northcentralus,northeurope,norwayeast,norwaywest,qatarcentral,southafricanorth,southafricawest,southcentralus,southeastasia,southindia,swedencentral,swedensouth,switzerlandnorth,switzerlandwest,uaecentral,uaenorth,uksouth,ukwest,westcentralus,westeurope,westindia,westus,westus2,westus3,israelcentral,italynorth,malaysiasouth,polandcentral,taiwannorth,taiwannorthwest]
    default = ["southeastasia","eastasia"]
    type    = list(string)
}

variable storagename {
    description = "Storage Account Name Prefix"
    default = "qliu"
    type    = string
}


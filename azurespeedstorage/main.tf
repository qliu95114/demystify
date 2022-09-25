locals {
}

resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_storage_account" "storage_account" {
  for_each                 = toset(var.locations)
  name                     = "${var.storagename}${each.key}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = each.key
  account_tier             = "Standard"
  account_replication_type = "LRS"
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "POST"]
      allowed_origins    = ["https://www.azurespeed.com,https://azurespeed-vnext.azurewebsites.net,http://localhost:4200,https://localhost:5001,http://localhost:3000,https://yellow-coast-0102b5200.1.azurestaticapps.net"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_management_policy" "delete_after_24h" {
  for_each           = toset(var.locations)
  #storage_account_id = "${var.storagename}${each.key}"
  storage_account_id = azurerm_storage_account.storage_account["${each.key}"].id
  rule {
    name    = "DeleteEarlierThan24Hours"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 1
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 1
      }
      version {
        delete_after_days_since_creation = 1
      }
    }
  }
}

/*resource "azurerm_storage_container" "private" {
  for_each             = toset(var.locations)
  name                 = "private"
  storage_account_name = "${var.storagename}${each.key}"
}

resource "azurerm_storage_container" "public" {
  for_each             = toset(var.locations)
  name                 = "public"
  storage_account_name = "${var.storagename}${each.key}"
}

resource "azurerm_storage_container" "upload" {
  for_each             = toset(var.locations)
  name                 = "upload"
  storage_account_name = "${var.storagename}${each.key}" 
}

resource "azurerm_storage_blob" "upload_test_100mb_file" {
  for_each               = toset(var.locations)
  name                   = "100MB.bin"
  storage_account_name   = "${var.storagename}${each.key}"
  storage_container_name = "private"
  type                   = "Block"
  source                 = "private/100MB.bin"
}

resource "azurerm_storage_blob" "latency_json" {
  for_each               = toset(var.locations)
  name                   = "latest.json"
  storage_account_name   = "${var.storagename}${each.key}"
  storage_container_name = "public"
  type                   = "Block"
  source                 = "public/latency-test.json"
}*/
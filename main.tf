############################################################
# Resource Group
############################################################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

############################################################
# Shared Image Gallery
############################################################
resource "azurerm_shared_image_gallery" "sig" {
  name                = var.shared_image_gallery.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  description         = var.shared_image_gallery.description
  tags                = var.tags

  dynamic "sharing" {
    for_each = (
      var.shared_image_gallery.sharing_permission != null &&
      var.shared_image_gallery.sharing_permission != "Private"
    ) ? [1] : []
    content {
      permission = var.shared_image_gallery.sharing_permission

      dynamic "community_gallery" {
        for_each = var.shared_image_gallery.sharing_permission == "Community" ? [1] : []
        content {
          eula            = var.shared_image_gallery.eula
          prefix          = var.shared_image_gallery.prefix
          publisher_email = var.shared_image_gallery.publisher_email
          publisher_uri   = var.shared_image_gallery.publisher_uri
        }
      }
    }
  }
}

############################################################
# Shared Image Definition (Windows 11 Gen2 + TL supported)
############################################################
resource "azurerm_shared_image" "si" {
  name                = var.shared_image.name
  gallery_name        = azurerm_shared_image_gallery.sig.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type = var.shared_image.os_type

  identifier {
    publisher = var.shared_image.publisher
    offer     = var.shared_image.offer
    sku       = var.shared_image.sku
  }

  description        = var.shared_image.description
  specialized        = false
  architecture       = coalesce(var.shared_image.architecture, "x64")
  hyper_v_generation = coalesce(var.shared_image.hyper_v_generation, "V2")

  trusted_launch_supported = true

  max_recommended_vcpu_count   = var.shared_image.max_recommended_vcpu_count
  min_recommended_vcpu_count   = var.shared_image.min_recommended_vcpu_count
  max_recommended_memory_in_gb = var.shared_image.max_recommended_memory_in_gb
  min_recommended_memory_in_gb = var.shared_image.min_recommended_memory_in_gb
  end_of_life_date             = var.shared_image.end_of_life_date

  tags = var.tags
}

############################################################
# AIB Identity + Permissions
############################################################
resource "azurerm_user_assigned_identity" "aib_uai" {
  name                = "aib-uai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "aib_rg_contrib" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aib_uai.principal_id
}

resource "azurerm_role_assignment" "aib_sig_contrib" {
  scope                = azurerm_shared_image_gallery.sig.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aib_uai.principal_id
}

############################################################
# Azure Image Builder Template
############################################################
locals {
  aib_body = {
    identity = {
      type = "UserAssigned"
      userAssignedIdentities = {
        (azurerm_user_assigned_identity.aib_uai.id) = {}
      }
    }
    properties = {
      buildTimeoutInMinutes = 240
      vmProfile             = { vmSize = "Standard_DS2_v2", osDiskSizeGB = 256 }
      source                = { type = "PlatformImage", publisher = "MicrosoftWindowsDesktop", offer = "windows-11", sku = "win11-24h2-avd", version = "latest" }
      customize = [
        {
          type = "PowerShell"
          name = "install-choco-and-packages"
          inline = [
            "Set-ExecutionPolicy Bypass -Scope Process -Force",
            "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12",
            "if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {",
            "  Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
            "  $env:Path += ';C:\\ProgramData\\chocolatey\\bin'",
            "}",
            "$apps=@('7zip','googlechrome'); foreach($p in $apps){ choco install $p -y --no-progress }"
          ]
        }
      ]
      distribute = [
        {
          type               = "SharedImage"
          galleryImageId     = azurerm_shared_image.si.id
          runOutputName      = "aibToSig"
          replicationRegions = var.replication_regions
          storageAccountType = "Standard_LRS"
          versioning         = { scheme = "Latest", major = var.image_version_major }
        }
      ]
    }
  }

  aib_name = "aib-win11-24h2-${substr(md5(jsonencode(local.aib_body.properties)), 0, 8)}"
}

resource "azapi_resource" "aib_template" {
  type      = "Microsoft.VirtualMachineImages/imageTemplates@2022-07-01"
  name      = local.aib_name
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  body      = jsonencode(local.aib_body)
}

# Trigger AIB build (runs on create/re-create)
resource "azapi_resource_action" "aib_run" {
  type        = "Microsoft.VirtualMachineImages/imageTemplates@2022-07-01"
  resource_id = azapi_resource.aib_template.id # <-- points to your template resource
  action      = "run"
  method      = "POST"

  timeouts { create = "180m" }

  # Re-run automatically if the template changes or you bump the variable

}


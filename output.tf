############################################################
# Resource Group
############################################################
output "resource_group" {
  description = "Resource Group details"
  value = {
    name     = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    id       = azurerm_resource_group.rg.id
  }
}

############################################################
# Compute Gallery & Image Definition
############################################################
output "shared_image_gallery" {
  value = {
    name     = azurerm_shared_image_gallery.sig.name
    location = azurerm_shared_image_gallery.sig.location
    id       = azurerm_shared_image_gallery.sig.id
  }
}

output "shared_image" {
  value = {
    name                     = azurerm_shared_image.si.name
    id                       = azurerm_shared_image.si.id
    os_type                  = azurerm_shared_image.si.os_type
    hyper_v_generation       = azurerm_shared_image.si.hyper_v_generation
    trusted_launch_supported = azurerm_shared_image.si.trusted_launch_supported
  }
}

############################################################
# AIB
############################################################
output "aib_template_id" {
  value       = azapi_resource.aib_template.id
  description = "AIB image template resource ID"
}

output "aib_run_started" {
  value       = true
  description = "True if AIB run was triggered"
}

############################################################
# Core
############################################################
variable "resource_group" {
  type    = object({ name = string, location = string })
  default = { name = "surajrgnew", location = "East US" }
}

# Azure Compute Gallery (SIG) — name cannot include hyphens
variable "shared_image_gallery" {
  type = object({
    name : string
    description : optional(string)
    sharing_permission : optional(string) # Private | Groups | Community
    eula : optional(string)
    prefix : optional(string)
    publisher_email : optional(string)
    publisher_uri : optional(string)
  })
  default = {
    name               = "sig_desktops"
    description        = "Windows 11 AVD images"
    sharing_permission = "Private"
  }
  validation {
    condition     = var.shared_image_gallery.sharing_permission == null || contains(["Private", "Groups", "Community"], var.shared_image_gallery.sharing_permission)
    error_message = "sharing_permission must be Private, Groups, or Community."
  }
}

# Image definition metadata (independent from the AIB source image)
variable "shared_image" {
  type = object({
    name : string
    os_type : string
    publisher : string
    offer : string
    sku : string
    description : optional(string)
    architecture : optional(string)       # x64 | Arm64
    hyper_v_generation : optional(string) # V1 | V2
    max_recommended_vcpu_count : optional(number)
    min_recommended_vcpu_count : optional(number)
    max_recommended_memory_in_gb : optional(number)
    min_recommended_memory_in_gb : optional(number)
    end_of_life_date : optional(string)
  })
  # Keep this aligned with the AIB source (below)
  default = {
    name               = "win11-24h2"
    os_type            = "Windows"
    publisher          = "MicrosoftWindowsDesktop"
    offer              = "windows-11"     # <-- NOTE the hyphen
    sku                = "win11-24h2-avd" # multi-session SKU available in East US
    description        = "Windows 11 24H2 (Gen2, Trusted Launch Supported)"
    architecture       = "x64"
    hyper_v_generation = "V2"
  }
  validation {
    condition     = contains(["Linux", "Windows"], var.shared_image.os_type)
    error_message = "os_type must be Linux or Windows."
  }
  validation {
    condition     = var.shared_image.architecture == null || contains(["x64", "Arm64"], var.shared_image.architecture)
    error_message = "architecture must be x64 or Arm64 if provided."
  }
  validation {
    condition     = var.shared_image.hyper_v_generation == null || contains(["V1", "V2"], var.shared_image.hyper_v_generation)
    error_message = "hyper_v_generation must be V1 or V2 if provided."
  }
}

# AIB replication target regions (display names)
variable "replication_regions" {
  type        = list(string)
  description = "Regions where AIB will replicate the SIG image"
  default     = ["eastus", "westeurope"]
}

############################################################
# App install + FSLogix (used by AIB customize)
############################################################
variable "choco_packages" {
  type    = list(string)
  default = ["7zip", "git", "notepadplusplus", "sysinternals"]
}

variable "winget_packages" {
  type    = list(string)
  default = ["Microsoft.VisualStudioCode", "Google.Chrome", "Microsoft.PowerToys"]
}

variable "fslogix_enable" {
  type    = bool
  default = true
}

variable "fslogix_roam_search" {
  type    = number
  default = 2
}

variable "fslogix_vhd_size_mb" {
  type    = number
  default = 30000
}

variable "fslogix_vhdx" {
  type    = bool
  default = true
}

variable "fslogix_mode" {
  type    = string
  default = "pooled" # informational
}

variable "fslogix_delete_local_profile_on_apply" {
  type    = bool
  default = true
}

variable "fslogix_prevent_login_with_failure" {
  type    = bool
  default = true
}

variable "fslogix_flipflop_dirname" {
  type    = bool
  default = true
}

variable "fslogix_vhd_locations" {
  type    = list(string)
  default = ["\\\\fileserver\\profiles"]
}

variable "fslogix_enable_cloud_cache" {
  type    = bool
  default = false
}

variable "fslogix_cc_locations" {
  type    = list(string)
  default = []
}

############################################################
# AIB → SIG automatic versioning
############################################################
# "Latest" → AIB creates next x.y.z under the chosen major
# "Source" → copy marketplace version (rarely used)
variable "image_version_scheme" {
  type    = string
  default = "Latest"
}

# Used when scheme = "Latest": versions like 25.0.1, 25.0.2, ...
variable "image_version_major" {
  type    = number
  default = 25
}

############################################################
# Tags
############################################################
variable "tags" {
  type = map(string)
  default = {
    Environment = "AVD-Image-Build"
    Terraform   = "true"
    Owner       = "suraj"
  }
}



variable "force_rebuild_id" {
  description = "Bump (e.g., timestamp) to force AIB run"
  type        = string
  default     = ""
}
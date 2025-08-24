variable "prefix" {
  type    = string
  default = "gha2"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "image_name" {
  type    = string
  default = "myapp"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "use_existing_acr" {
  type    = bool
  default = false
  validation {
    condition     = !(var.use_existing_acr == true && var.existing_acr_name == "" && var.existing_acr_id == "" && var.existing_acr_login_server == "")
    error_message = "When use_existing_acr is true you must provide at least one of existing_acr_name, existing_acr_id, or existing_acr_login_server."
  }
}

variable "existing_acr_name" {
  type    = string
  default = ""
  validation {
  condition     = var.existing_acr_name == "" || can(regex("^[a-z0-9]+$", var.existing_acr_name))
  error_message = "existing_acr_name must be empty or contain only lowercase alphanumeric characters (no hyphens). If your registry name contains other characters, provide existing_acr_id or existing_acr_login_server instead."
  }
}

variable "existing_acr_rg" {
  type    = string
  default = ""
}

variable "acr_admin_username" {
  type    = string
  default = ""
}

variable "acr_admin_password" {
  type    = string
  default = ""
  sensitive = true
}

variable "existing_acr_id" {
  type    = string
  default = ""
}

variable "existing_acr_login_server" {
  type    = string
  default = ""
}

variable "container_port" {
  type    = string
  default = "80"
  description = "Port the container listens on. App Service will be configured with WEBSITES_PORT to route traffic to this port."
}

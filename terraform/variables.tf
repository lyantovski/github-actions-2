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

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

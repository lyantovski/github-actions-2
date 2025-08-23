resource "azurerm_resource_group" "rg" {
  count    = var.use_existing_acr ? 0 : 1
  name     = "${var.prefix}-rg"
  location = var.location
}

# Create a new ACR only when not using an existing one
resource "azurerm_container_registry" "acr" {
  count               = var.use_existing_acr ? 0 : 1
  name                = "${var.prefix}acr"
  resource_group_name = local.target_rg_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Data source for existing ACR when use_existing_acr = true
data "azurerm_container_registry" "existing" {
  count = var.use_existing_acr && var.existing_acr_id == "" && var.existing_acr_login_server == "" && var.existing_acr_name != "" ? 1 : 0
  name  = var.existing_acr_name
  resource_group_name = var.existing_acr_rg
}

locals {
  target_rg_name = var.use_existing_acr ? var.existing_acr_rg : azurerm_resource_group.rg[0].name
  acr_login_server = var.use_existing_acr ? (var.existing_acr_login_server != "" ? var.existing_acr_login_server : (var.existing_acr_id != "" ? "" : data.azurerm_container_registry.existing[0].login_server)) : azurerm_container_registry.acr[0].login_server
  acr_id = var.use_existing_acr ? (var.existing_acr_id != "" ? var.existing_acr_id : (var.existing_acr_name != "" ? data.azurerm_container_registry.existing[0].id : azurerm_container_registry.acr[0].id)) : azurerm_container_registry.acr[0].id
  acr_admin_username = var.use_existing_acr ? (var.acr_admin_username != "" ? var.acr_admin_username : "") : azurerm_container_registry.acr[0].admin_username
  acr_admin_password = var.use_existing_acr ? (var.acr_admin_password != "" ? var.acr_admin_password : "") : azurerm_container_registry.acr[0].admin_password
}

resource "azurerm_service_plan" "plan" {
  name                = "${var.prefix}-plan"
  location            = var.location
  resource_group_name = local.target_rg_name
  sku_name            = "B1"
  os_type             = "Linux"

  # 'kind' and 'reserved' are computed by the provider and must not be set.
}

resource "azurerm_linux_web_app" "app" {
  name                = "${var.prefix}-app"
  location            = var.location
  resource_group_name = local.target_rg_name
  service_plan_id     = azurerm_service_plan.plan.id
  # The provider computes linux_fx_version automatically for Linux container apps
    site_config {}
  # Set the container image via the DOCKER_CUSTOM_IMAGE_NAME app setting instead.
  app_settings = merge(
    {
      "DOCKER_CUSTOM_IMAGE_NAME"   = "${local.acr_login_server}/${var.image_name}:${var.image_tag}"
      "DOCKER_REGISTRY_SERVER_URL" = "https://${local.acr_login_server}"
    },
    local.acr_admin_username != "" && local.acr_admin_password != "" ? {
      "DOCKER_REGISTRY_SERVER_USERNAME" = local.acr_admin_username
      "DOCKER_REGISTRY_SERVER_PASSWORD" = local.acr_admin_password
    } : {}
  )

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [app_settings]
  }
}

# Ensure the app's managed identity has AcrPull on the registry so it can pull images from ACR
resource "random_uuid" "role_id" {}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
  name                 = random_uuid.role_id.result
  depends_on           = [azurerm_linux_web_app.app]
}

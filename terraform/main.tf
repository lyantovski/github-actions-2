resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Create a new ACR only when not using an existing one
resource "azurerm_container_registry" "acr" {
  count               = var.use_existing_acr ? 0 : 1
  name                = "${var.prefix}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Data source for existing ACR when use_existing_acr = true
data "azurerm_container_registry" "existing" {
  count = var.use_existing_acr ? 1 : 0
  name  = var.existing_acr_name
  resource_group_name = var.existing_acr_rg
}

locals {
  acr_login_server = var.use_existing_acr ? data.azurerm_container_registry.existing[0].login_server : azurerm_container_registry.acr[0].login_server
  acr_id = var.use_existing_acr ? data.azurerm_container_registry.existing[0].id : azurerm_container_registry.acr[0].id
  acr_admin_username = var.use_existing_acr ? (var.acr_admin_username != "" ? var.acr_admin_username : "") : azurerm_container_registry.acr[0].admin_username
  acr_admin_password = var.use_existing_acr ? (var.acr_admin_password != "" ? var.acr_admin_password : "") : azurerm_container_registry.acr[0].admin_password
}

resource "azurerm_app_service_plan" "plan" {
  name                = "${var.prefix}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = "${var.prefix}-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.plan.id

  site_config {
    linux_fx_version = "DOCKER|${local.acr_login_server}/${var.image_name}:${var.image_tag}"
  }

  app_settings = merge(
    {
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
  principal_id         = azurerm_linux_web_app.app.identity.principal_id
  name                 = random_uuid.role_id.result
  depends_on           = [azurerm_linux_web_app.app]
}

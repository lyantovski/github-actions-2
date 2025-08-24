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
  # Try extracting resource group from existing_acr_id when possible
  # Safely extract resource group from existing_acr_id if present. Use can() to avoid invalid index errors.
  # extract resource group name from an existing resource id by splitting the id
  # Azure resource id format: /subscriptions/{sub}/resourceGroups/{rg}/providers/...
  rg_from_id = var.existing_acr_id != "" && can(element(split("/", var.existing_acr_id), 4)) ? element(split("/", var.existing_acr_id), 4) : (can(regexall("resourcegroups/([^/]+)/", lower(var.existing_acr_id))[0][1]) ? regexall("resourcegroups/([^/]+)/", lower(var.existing_acr_id))[0][1] : "")

  # Try extracting the registry name from the ACR resource id when provided
  # Azure ACR resource id segments: ['', 'subscriptions', '{sub}', 'resourceGroups', '{rg}', 'providers', 'Microsoft.ContainerRegistry', 'registries', '{name}']
  acr_name_from_id = var.existing_acr_id != "" && can(element(split("/", var.existing_acr_id), 8)) ? element(split("/", var.existing_acr_id), 8) : ""

  target_rg_name = var.use_existing_acr ? (
    var.existing_acr_rg != "" ? var.existing_acr_rg : (
      var.existing_acr_id != "" && local.rg_from_id != "" ? local.rg_from_id : (
    var.existing_acr_name != "" && length(data.azurerm_container_registry.existing) > 0 ? data.azurerm_container_registry.existing[0].resource_group_name : (can(azurerm_resource_group.rg[0].name) ? azurerm_resource_group.rg[0].name : "")
      )
    )
  ) : (can(azurerm_resource_group.rg[0].name) ? azurerm_resource_group.rg[0].name : "")

  # Determine the login server for the registry. Priority:
  # 1) explicit existing_acr_login_server input
  # 2) if existing_acr_id provided, derive name from id and use <name>.azurecr.io
  # 3) data.azurerm_container_registry when name+rg were provided
  # 4) newly created azurerm_container_registry
  acr_login_server = var.use_existing_acr ? (
    var.existing_acr_login_server != "" ? var.existing_acr_login_server : (
      var.existing_acr_id != "" && local.acr_name_from_id != "" ? "${local.acr_name_from_id}.azurecr.io" : (
        length(data.azurerm_container_registry.existing) > 0 && can(data.azurerm_container_registry.existing[0].login_server) ? data.azurerm_container_registry.existing[0].login_server : ""
      )
    )
  ) : (can(azurerm_container_registry.acr[0].login_server) ? azurerm_container_registry.acr[0].login_server : "")

  # Normalize login server: remove any leading scheme and trailing slash so callers can build URLs reliably
  # Remove leading scheme and any slashes (common user inputs might include https:// or a trailing slash)
  acr_login_server_clean = local.acr_login_server != "" ? replace(replace(replace(local.acr_login_server, "https://", ""), "http://", ""), "/", "") : ""
  acr_id = var.use_existing_acr ? (var.existing_acr_id != "" ? var.existing_acr_id : (var.existing_acr_name != "" && length(data.azurerm_container_registry.existing) > 0 && can(data.azurerm_container_registry.existing[0].id) ? data.azurerm_container_registry.existing[0].id : (can(azurerm_container_registry.acr[0].id) ? azurerm_container_registry.acr[0].id : ""))) : (can(azurerm_container_registry.acr[0].id) ? azurerm_container_registry.acr[0].id : "")
  acr_admin_username = var.use_existing_acr ? (var.acr_admin_username != "" ? var.acr_admin_username : "") : (can(azurerm_container_registry.acr[0].admin_username) ? azurerm_container_registry.acr[0].admin_username : "")
  acr_admin_password = var.use_existing_acr ? (var.acr_admin_password != "" ? var.acr_admin_password : "") : (can(azurerm_container_registry.acr[0].admin_password) ? azurerm_container_registry.acr[0].admin_password : "")
}

# Helpful validation hint: when using an existing ACR, ensure at least one identifier is provided.
locals {
  acr_input_provided = ! (var.use_existing_acr == true && var.existing_acr_name == "" && var.existing_acr_id == "" && var.existing_acr_login_server == "")
}

output "acr_validation_hint" {
  description = "Shows a helpful hint when use_existing_acr = true but no ACR identifier was provided."
  value       = var.use_existing_acr && !local.acr_input_provided ? "use_existing_acr is true but no existing_acr_name, existing_acr_id or existing_acr_login_server were provided. Provide at least one." : ""
  sensitive   = false
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
  # Use cleaned host so DOCKER_REGISTRY_SERVER_URL becomes https://<host>
  # and DOCKER_CUSTOM_IMAGE_NAME becomes <host>/name:tag
  "DOCKER_CUSTOM_IMAGE_NAME"   = "${local.acr_login_server_clean}/${var.image_name}:${var.image_tag}"
  "DOCKER_REGISTRY_SERVER_URL" = "https://${local.acr_login_server_clean}"
      "WEBSITES_PORT" = var.container_port
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

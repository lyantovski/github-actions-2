output "app_default_hostname" {
  value = azurerm_linux_web_app.app.default_site_hostname
}

output "acr_login_server" {
  value = local.acr_login_server
}

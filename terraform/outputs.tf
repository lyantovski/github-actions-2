output "app_default_hostname" {
  value = "${azurerm_linux_web_app.app.name}.azurewebsites.net"
}

output "acr_login_server" {
  value = local.acr_login_server
}

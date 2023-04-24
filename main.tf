module "cluster" {
  source = "./cluster"
  azure_vault_url = var.azure_vault_url
  azure_vault_name = var.azure_vault_name
  tube_vnet = var.tube_vnet
}

module "app" {
  source      = "./app"
  config_path = module.cluster.kubeconfig_path

  azurerm_kubernetes_cluster_this = module.cluster.azurerm_kubernetes_cluster_this
  kubernetes_namespace_rabbitmq = module.cluster.kubernetes_namespace_rabbitmq
  kubernetes_namespace_mariadb = module.cluster.kubernetes_namespace_mariadb

  azure_client_secret = var.azure_client_secret
  azure_client_id = var.azure_client_id
  azure_tenant_id = var.azure_tenant_id
  azure_vault_url = var.azure_vault_url
  docker_server = var.docker_server
  docker_username = var.docker_username
  docker_password = var.docker_password
  azure_vault_name = var.azure_vault_name
  azkv_resource_group_name = var.azkv_resource_group_name
}
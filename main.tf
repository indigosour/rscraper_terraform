module "cluster" {
  source = "./cluster"
  azure_vault_url = var.azure_vault_url
  azure_vault_name = var.azure_vault_name
  tube_vnet = var.tube_vnet
}

module "app" {
  source      = "./app" 
  depends_on = [
    module.cluster
  ]

  # Kubernetes cluster configuration
  kube_host     = module.cluster.kube_host
  kube_client_certificate = module.cluster.kube_client_certificate
  kube_client_key = module.cluster.kube_client_key
  
  # Azure configuration
  azure_client_secret = var.azure_client_secret
  azure_client_id = var.azure_client_id
  azure_tenant_id = var.azure_tenant_id
  azure_vault_url = var.azure_vault_url
  azure_vault_name = var.azure_vault_name
  azkv_resource_group_name = var.azkv_resource_group_name
  
  # GHCR.io configuration
  docker_server = var.docker_server
  docker_username = var.docker_username
  docker_password = var.docker_password
}
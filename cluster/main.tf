provider "azurerm" {
  features {}
}


################################################################
######################## Variables #############################
################################################################

resource "kubernetes_namespace" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }
}

resource "kubernetes_namespace" "mariadb" {
  metadata {
    name = "mariadb"    
  }
}

locals {cluster_name = "prodk8"}

resource "azurerm_resource_group" "this" {
  name     = "rscraper_prod"
  location = "North Central US"
}


################################################################
######################## Deploy AKS ############################
################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = local.cluster_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2ms"
    os_sku = "Ubuntu"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Terraform = "true"
    Environment = "prod"
  }
}

resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.this]
  filename = "kubeconfig.yaml"
  content  = azurerm_kubernetes_cluster.this.kube_config_raw
}


################################################################
####################### AKS NET CONFIG #########################
################################################################

# data "azurerm_subnet" "aks_subnet" {
#   name = "default"
#   resource_group_name = azurerm_resource_group.this.name
#   virtual_network_name = basename(azurerm_kubernetes_cluster.this.network_profile[0].service_cidr)
# }

# data "azurerm_virtual_network" "aks_vnet" {
#   name                = data.azurerm_subnet.aks_subnet.virtual_network_name
#   resource_group_name = azurerm_resource_group.this.name
# }

# resource "azurerm_virtual_network_peering" "aks_to_tube_vnet" {
#   name                         = "AKS_TO_TUBE"
#   resource_group_name          = azurerm_resource_group.this.name
#   virtual_network_name         = data.azurerm_virtual_network.aks_vnet.name
#   remote_virtual_network_id    = var.tube_vnet
#   allow_virtual_network_access = true
#   allow_forwarded_traffic = false
# }

# resource "azurerm_virtual_network_peering" "other_vnet_to_aks" {
#   name                         = "TUBE_TO_AKS"
#   resource_group_name          = "tube"
#   virtual_network_name         = "tube-vnet"
#   remote_virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic = false
# }



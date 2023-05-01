################################################################
######################## Variables #############################
################################################################

resource "azurerm_resource_group" "this" {
  name     = "rscraper_prod"
  location = "North Central US"
}


################################################################
######################## Deploy AKS ############################
################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name

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
    Environment = var.environment
  }
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
variable "azure_vault_url" {
  description = "Azure Vault URL"
  type        = string
}

variable "azure_vault_name" {
  description = "Azure Vault Name"
  type = string
}

variable "tube_vnet" {
  description = "Azure Virtual Network ID for the Tube VNet"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default = "rscraper-aks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default = "dev"
}
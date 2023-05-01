variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "azure_client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "azure_client_secret" {
  description = "Azure Client Secret"
  type        = string
}

variable "azure_vault_url" {
  description = "Azure Vault URL"
  type        = string
}

variable "azure_vault_name" {
  description = "Azure Vault Name"
  type = string
}

variable "docker_server" {
  description = "Docker registry server"
  type        = string
}

variable "docker_username" {
  description = "Docker registry username"
  type        = string
}

variable "docker_password" {
  description = "Docker registry password"
  type        = string
}

variable "azkv_resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "kube_host" {
  description = "kube_host from the cluster module"
  type        = string
}

variable "kube_client_certificate" {
  description = "kube_client_certificate from the cluster module"
  type        = string
}

variable "kube_client_key" {
  description = "kube_client_key from the cluster module"
  type        = string
}
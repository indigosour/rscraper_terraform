output "kubeconfig_path" {
  value       = local_file.kubeconfig.filename
  description = "Path to the kubeconfig file."
}

output "azurerm_kubernetes_cluster_this" {
  value = azurerm_kubernetes_cluster.this
}

output "kubernetes_namespace_rabbitmq" {
  value = kubernetes_namespace.rabbitmq
}

output "kubernetes_namespace_mariadb" {
  value = kubernetes_namespace.mariadb
}
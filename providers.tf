provider "kubernetes" {
  host                   = module.cluster.kube_host
  client_certificate     = base64decode(module.cluster.kube_client_certificate)
  client_key             = base64decode(module.cluster.kube_client_key)
  insecure         = "true"
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.kube_host
    client_certificate     = base64decode(module.cluster.kube_client_certificate)
    client_key             = base64decode(module.cluster.kube_client_key)
    insecure         = "true"
  }
}

provider "azurerm" {
  features {}
}

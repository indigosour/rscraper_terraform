provider "azurerm" {
  features {}
}


################################################################
######################### Secrets ##############################
################################################################

resource "azurerm_key_vault" "az_key_vault" {
  name                       = var.azure_vault_name
  location                   = "East US"
  resource_group_name        = var.azkv_resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "DB-CRED" {
  name         = "DB-CRED"
  key_vault_id = azurerm_key_vault.az_key_vault.id
}

locals {
  db_cred = jsondecode(data.azurerm_key_vault_secret.DB-CRED.value)
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

resource "null_resource" "wait_for_cluster" {
  depends_on = [azurerm_kubernetes_cluster.this]

  provisioner "local-exec" {
    command = "until kubectl get nodes --kubeconfig=${azurerm_kubernetes_cluster.this.kube_config_raw} | grep ' Ready '; do echo 'Waiting for cluster to be ready...'; sleep 30; done"
  }
}

resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.this, null_resource.wait_for_cluster]
  filename = abspath("${path.module}/kubeconfig.yaml")
  content  = azurerm_kubernetes_cluster.this.kube_config_raw
}


provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
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


################################################################
####################### Deploy Secrets #########################
################################################################

resource "kubernetes_secret" "rscraper_env" {
  depends_on = [azurerm_kubernetes_cluster.this]
  metadata {
    name = "rscraper-env"
    namespace = "default"
  }

  data = {
    AZURE_TENANT_ID       = var.azure_tenant_id
    AZURE_CLIENT_ID       = var.azure_client_id
    AZURE_CLIENT_SECRET   = var.azure_client_secret
    AZURE_VAULT_URL       = var.azure_vault_url
  }
}

resource "kubernetes_secret" "regcred" {
  depends_on = [azurerm_kubernetes_cluster.this]
  metadata {
    name      = "regcred"
    namespace = "default"
  }

  data = {
    docker-server = var.docker_server
    username = var.docker_username
    password = var.docker_password
      }
  }


################################################################
############# Deploy application dependancies ##################
################################################################


resource "helm_release" "rabbitmq" {
  depends_on = [azurerm_kubernetes_cluster.this,null_resource.wait_for_cluster]

  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  namespace = kubernetes_namespace.rabbitmq.metadata[0].name

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = ""
  }

  set {
    name  = "persistence.accessMode"
    value = "ReadWriteOnce"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}

resource "helm_release" "mariadb" {
  depends_on = [azurerm_kubernetes_cluster.this,null_resource.wait_for_cluster]

  name       = "mariadb"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mariadb"
  namespace  = kubernetes_namespace.mariadb.metadata[0].name

  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.storageClassName"
    value = ""
  }

  set {
    name  = "primary.persistence.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "primary.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "auth.password"
    value =  local.db_cred["password"]
  }

  set {
    name  = "auth.username"
    value =  local.db_cred["username"]
  }
}


################################################################
############# Deploy application services ######################
################################################################

resource "kubernetes_manifest" "rscraper_conductor_deployment" {
  depends_on = [
    azurerm_kubernetes_cluster.this,
    null_resource.wait_for_cluster,
    kubernetes_namespace.rabbitmq,
    kubernetes_namespace.mariadb
    ]

  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "name" = "rscraper-conductor"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "rscraper-conductor"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "rscraper-conductor"
          }
        }
        "spec" = {
          "containers" = [
            {
              "name"  = "rscraper-conductor"
              "image" = "ghcr.io/indigosour/rscraper_conductor:1.0.5"
              "ports" = [
                {
                  "containerPort" = 5000
                }
              ]
              "envFrom" = [
                {
                  "secretRef" = {
                    "name" = "rscraper-env"
                  }
                }
              ]
              "imagePullSecrets" = [
                {
                  "name" = "regcred"
                }
              ]
            }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "rscraper_conductor_service" {
    depends_on = [
    azurerm_kubernetes_cluster.this,
    null_resource.wait_for_cluster,
    kubernetes_namespace.rabbitmq,
    kubernetes_namespace.mariadb,
    kubernetes_manifest.rscraper_conductor_deployment
    ]

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Service"
    "metadata" = {
      "name" = "rscraper-conductor-service"
    }
    "spec" = {
      "selector" = {
        "app" = "rscraper-conductor"
      }
      "ports" = [
        {
          "protocol"   = "TCP"
          "port"       = 5000
          "targetPort" = 5000
        }
      ]
      "type" = "ClusterIP"
    }
  }
}

resource "kubernetes_manifest" "rscraper_worker_deployment" {
    depends_on = [
    azurerm_kubernetes_cluster.this,
    null_resource.wait_for_cluster,
    kubernetes_namespace.rabbitmq,
    kubernetes_namespace.mariadb,
    kubernetes_manifest.rscraper_conductor_deployment,
    kubernetes_manifest.rscraper_conductor_service
    ]

  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "name" = "rscraper-worker"
    }
    "spec" = {
      "replicas" = 4
      "selector" = {
        "matchLabels" = {
          "app" = "rscraper-worker"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "rscraper-worker"
          }
        }
        "spec" = {
          "containers" = [
            {
              "name"  = "rscraper-worker"
              "image" = "ghcr.io/indigosour/rscraper_worker:1.0.0"
              "envFrom" = [
                {
                  "secretRef" = {
                    "name" = "rscraper-env"
                  }
                }
              ]
              "imagePullSecrets" = [
                {
                  "name" = "regcred"
                }
              ]
            }
          ]
        }
      }
    }
  }
}
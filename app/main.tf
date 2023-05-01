################################################################
######################### Secrets ##############################
################################################################

data "azurerm_key_vault" "az_key_vault" {
  name                       = var.azure_vault_name
  resource_group_name        = var.azkv_resource_group_name
}

data "azurerm_key_vault_secret" "DB_CRED" {
  name         = "DB-CRED"
  key_vault_id = data.azurerm_key_vault.az_key_vault.id
}

locals {
  db_cred = jsondecode(data.azurerm_key_vault_secret.DB_CRED.value)
}


################################################################
####################### Deploy Secrets #########################
################################################################

resource "kubernetes_secret" "rscraper_env" {
  depends_on = []
  metadata {
    name = "rscraper-env"
    namespace = kubernetes_namespace.rscraper.metadata[0].name
  }

  data = {
    AZURE_TENANT_ID       = var.azure_tenant_id
    AZURE_CLIENT_ID       = var.azure_client_id
    AZURE_CLIENT_SECRET   = var.azure_client_secret
    AZURE_VAULT_URL       = var.azure_vault_url
  }
}

resource "kubernetes_secret" "regcred" {
  depends_on = []
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

resource "kubernetes_namespace" "rscraper" {
  metadata {
    name = "rscraper"
  }
}

resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  namespace = kubernetes_namespace.rscraper.metadata[0].name

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
  name       = "mariadb"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mariadb"
  namespace = kubernetes_namespace.rscraper.metadata[0].name

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
    helm_release.rabbitmq,
    helm_release.mariadb
    ]

  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "name" = "rscraper-conductor"
      "namespace" = kubernetes_namespace.rscraper.metadata[0].name
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
    helm_release.rabbitmq,
    helm_release.mariadb,
    kubernetes_manifest.rscraper_conductor_deployment
    ]

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Service"
    "metadata" = {
      "name" = "rscraper-conductor-service"
      "namespace" = kubernetes_namespace.rscraper.metadata[0].name
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
    helm_release.rabbitmq,
    helm_release.mariadb,
    kubernetes_manifest.rscraper_conductor_service
    ]

  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "name" = "rscraper-worker"
      "namespace" = kubernetes_namespace.rscraper.metadata[0].name
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
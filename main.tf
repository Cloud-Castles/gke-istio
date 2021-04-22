terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.64.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.1.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.1.1"
    }
  }
  required_version = ">= 0.14"
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "kubernetes" {
  host = google_container_cluster.gke_cluster.endpoint

  cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host = google_container_cluster.gke_cluster.endpoint

    cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

data "google_client_config" "default" {
}


#CREATING GKE CLUSTER
resource "google_service_account" "sa" {
  account_id  = var.gke_cluster_name
  description = "GKE service account"
}

resource "google_project_iam_member" "sa_permissions" {
  for_each           = toset(var.gke_sa_roles)
  project = var.gcp_project
  member = "serviceAccount:${google_service_account.sa.email}"
  role = each.key
}

resource "google_container_cluster" "gke_cluster" {
  name                     = var.gke_cluster_name
  location                 = var.gcp_region
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "pool" {
  name               = var.gke_node_pool_name
  location           = google_container_cluster.gke_cluster.location
  cluster            = google_container_cluster.gke_cluster.name
  initial_node_count = 1

  node_config {
    service_account = google_service_account.sa.email
    machine_type    = var.gke_machine_type
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
}

#DEPLOYING ISTIO

resource "null_resource" "download_istio" {
  provisioner "local-exec" {
    command = "curl -L https://istio.io/downloadIstio | sh -"
  }
}

resource "helm_release" "istio_base" {

  depends_on       = [null_resource.download_istio]
  name             = "istio-base"
  chart            = "./istio-1.9.3/manifests/charts/base"
  namespace        = var.istio_namespace
  create_namespace = true
}

resource "helm_release" "istiod" {
  name      = "istiod"
  chart     = "./istio-1.9.3/manifests/charts/istio-control/istio-discovery"
  namespace = helm_release.istio_base.namespace
}

resource "helm_release" "istio_ingress" {
  name      = "istio-ingress"
  chart     = "./istio-1.9.3/manifests/charts/gateways/istio-ingress"
  namespace = helm_release.istio_base.namespace

}

resource "null_resource" "prepare_kubectl" {

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.gke_cluster.name} --region=${google_container_cluster.gke_cluster.location} --project=${var.gcp_project}"
    environment = {
      KUBECONFIG = ".kube/nginx-cluster"
    }
  }
}

resource "null_resource" "istio_config" {
  depends_on = [helm_release.istio_base]

  triggers = {
    istio_config = filesha256("istio-config.yaml")
  }

  provisioner "local-exec" {
    command = "kubectl apply -f istio-config.yaml -n ${kubernetes_namespace.nginx_ns.metadata.0.name}"
    environment = {
      KUBECONFIG = ".kube/nginx-cluster"
    }
  }
}

resource "kubernetes_namespace" "nginx_ns" {
  depends_on = [google_container_node_pool.pool]
  #without this dependency "terraform destroy" fails with timeout

  metadata {
    name = "nginx"
    labels = {
      istio-injection = "enabled"
    }
  }
}

#DEPLOYNG NGINX
resource "helm_release" "nginx" {
  depends_on = [helm_release.istiod]
  #need to deploy istio first to ensure side car injection

  name       = "my-nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  version    = "8.8.3"
  namespace  = kubernetes_namespace.nginx_ns.metadata.0.name

  set {
    name  = "replicaCount"
    value = var.nginx_instances_count
  }

  set {
    name  = "podAntiAffinityPreset"
    value = "hard"
  }

  set {
    name  = "staticSiteConfigmap"
    value = kubernetes_config_map.site.metadata.0.name
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}

resource "kubernetes_config_map" "site" {
  metadata {
    name      = var.config_map_name
    namespace = kubernetes_namespace.nginx_ns.metadata.0.name
  }

  data = {
    "index.html" = file("index.html")
  }
}

data "kubernetes_service" "istio_ig" {

  metadata {
    name      = var.istio_gw_name
    namespace = helm_release.istio_ingress.namespace
  }
}

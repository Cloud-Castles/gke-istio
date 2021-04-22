variable "gke_cluster_name" {
  default     = "nginx-cluster"
  type        = string
  description = "GKE cluster name"
}

variable "gke_node_pool_name" {
  default     = "nginx-nodes"
  type        = string
  description = "GKE nodes pool name"
}


variable "gcp_region" {
  default     = "europe-west3"
  type        = string
  description = "GCP region"
}

variable "gcp_project" {
  type        = string
  description = "GCP project name"
}

variable "gke_machine_type" {
  default     = "e2-standard-2"
  type        = string
  description = "GKE node machine type"
}

variable "gke_sa_roles" {
  default     = ["roles/monitoring.metricWriter", "roles/logging.logWriter"]
  type        = list(string)
  description = "permissions for GKE service account"
}

variable "nginx_instances_count" {
  default     = 3
  type        = number
  description = "number of nginx pods for deploy"
}

variable "config_map_name" {
  default     = "investing-static-site"
  type        = string
  description = "k8s config map name"
}

variable "istio_gw_name" {
  default     = "istio-ingressgateway"
  type        = string
  description = "name for istio gateway"
}

variable "istio_namespace" {
  default     = "istio-system"
  type        = string
  description = "k8s namespace for istio components"
}

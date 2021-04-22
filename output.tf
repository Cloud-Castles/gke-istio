output "nginx_external_ip" {
  value = "http://${data.kubernetes_service.istio_ig.status.0.load_balancer.0.ingress.0.ip}"
}

output "gcloud_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.gke_cluster.name} --region=${google_container_cluster.gke_cluster.location}"
}

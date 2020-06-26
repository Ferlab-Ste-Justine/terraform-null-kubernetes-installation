output "id" {
    description = "ID uniquely identifying the last kubernetes installation"
    value = null_resource.kubernetes_installation.id
}
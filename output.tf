output "id" {
    description = "ID uniquely identifying the last terraform installation"
    value = null_resource.kubernetes_installation.id
}
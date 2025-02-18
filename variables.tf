variable "master_ips" {
  description = "Ips of the k8 masters"
  type = list(string)
}

variable "worker_ips" {
  description = "Ips of the k8 workers"
  type = list(string)
}

variable "load_balancer_ips" {
  description = "Ips of the load balancer"
  type = list(string)
  default = []
}

variable "bastion_external_ip" {
  description = "External ip of the bastion"
  type = string
}

variable "bastion_port" {
  description = "Ssh port the bastion uses"
  type = number
  default = 22
}

variable "bastion_user" {
  description = "User to ssh on the bastion as"
  type = string
  default = "ubuntu"
}

variable "k8_cluster_user" {
  description = "User to ssh on k8 machines as"
  type = string
  default = "ubuntu"
}

variable "bastion_key_pair" {
  description = "SSh key pair"
  type = any
}

variable "provisioning_path" {
  description = "Directory to put kubernetes provisioning files in. This directory will be deleted after the installation."
  type = string
}

variable "artifacts_path" {
  description = "Directory where to put post-installation admin.conf file and kubectl binary"
  type = string
}

variable "cloud_init_sync_path" {
  description = "Directory to put cloud-init synchronization ansible files in"
  type = string
}

variable "certificates_path" {
  description = "Directory to upload pre-generated private keys and certificates in"
  type = string
}

variable "bastion_dependent_ip" {
  description = "Internal ip of the bastion. Required only to set a provisioning dependency on the bastion. Not used otherwise."
  type = string
}

variable "wait_on_ips" {
    description = "Ips of extra vms (beyond the workers, masters and bastion) that the provisioner wait on for cloud-init. If your api load balancer is a vm, you should put it there."
    type = any
}

variable "revision" {
  description = "Internal version of the module to force reprovisioning on changes. Should usually be left to default value to reprovision with incremental versions."
  type = string
  default = "1.1.0"
}

variable "k8_ingress_http_port" {
  description = "Port that will be taken up on all kubernetes workers for ingress http traffic"
  type = number
  default = 30000
}

variable "k8_ingress_https_port" {
  description = "Port that will be taken up on all kubernetes workers for ingress https traffic"
  type = number
  default = 30001
}

variable "k8_cluster_name" {
  description = "Name of the k8 cluster in the configuration"
  type = string
  default = "cluster.local"
}

variable "k8_version" {
  description = "Kubernetes version to install"
  type = string
  default = "v1.29.5"
}

variable "custom_container_repos" {
  description = "Non-default container repos. Image names can be left with the empty string to go with the default"
  type        = object({
    enabled     = bool
    registry    = string
    image_names = object({
      coredns                  = string
      dnsautoscaler            = string
      ingress_nginx_controller = string
      nodelocaldns             = string
      pause                    = string
    })
  })
  default = {
    enabled     = false
    registry    = ""
    image_names = {
      coredns                  = ""
      dnsautoscaler            = ""
      ingress_nginx_controller = ""
      nodelocaldns             = ""
      pause                    = ""
    }
  }
}

variable "ca_certificate" {
  description = "Ca certificate in pem format"
  type = string
  default = ""
}

variable "ca_private_key" {
  description = "Ca private key"
  type = string
  default = ""
}

variable "etcd_ca_certificate" {
  description = "Etcd ca certificate in pem format"
  type = string
  default = ""
}

variable "etcd_ca_private_key" {
  description = "Etcd private key"
  type = string
  default = ""
}

variable "front_proxy_ca_certificate" {
  description = "Front proxy ca certificate in pem format"
  type = string
  default = ""
}

variable "front_proxy_ca_private_key" {
  description = "Front proxy private key"
  type = string
  default = ""
}

variable "kubespray_repo" {
  description = "Repository to clone kubespray from"
  type = string
  default = "https://github.com/kubernetes-sigs/kubespray.git"
}

variable "kubespray_repo_ref" {
  description = "Tag or branch to checkout once the repository is cloned"
  type = string
  default = "v2.25.0"
}

variable "kubespray_image" {
  description = "Docker image of kubespray"
  type = string
  default = "quay.io/kubespray/kubespray:v2.25.0"
}

variable "ingress_arguments" {
  description = "List of arguments to pass to the nginx ingress. Hyphens should be included in the values."
  type = list(string)
  default = []
}

variable "ingress_version" {
  description = "Version of the nginx ingress. Specify only if you wish to override the default version specified in kubespray"
  type = string
  default = ""
}

variable "container_registry_credentials" {
  description = "Credentials to dependent container registries"
  type = list(object({
    registry = string
    username = string
    password = string
  }))
  default = []
}

variable "calico" {
  description = "Some configurable parameters for Calico"
  type = object({
    iptables_backend   = string
    //https://docs.tigera.io/calico/latest/networking/configuring/mtu#determine-mtu-size
    mtu                = number
    //https://docs.tigera.io/calico/latest/networking/determine-best-networking#networking-options
    //https://docs.tigera.io/calico/latest/networking/configuring/bgp
    network_backend    = string
    encapsulation_mode = string
  })
  default = {
    iptables_backend   = "Legacy"
    mtu                = 1480
    network_backend    = "bird"
    encapsulation_mode = "Always"
  }
}
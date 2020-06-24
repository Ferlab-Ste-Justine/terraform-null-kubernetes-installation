variable "master_ips" {
  description = "Ips of the k8 masters"
  type = list(string)
}

variable "worker_ips" {
  description = "Ips of the k8 workers"
  type = list(string)
}


variable "load_balancer_external_ip" {
  description = "External ip of the load balancer"
  type = string
}

variable "bastion_external_ip" {
  description = "External ip of the bastion"
  type = string
}

variable "bastion_key_pair" {
  description = "SSh key pair"
  type = any
}

variable "kubespray_path" {
  description = "Directory to put kubespray ansible files in"
  type = string
}

variable "cloud_init_sync_path" {
  description = "Directory to put cloud-init synchronization ansible files in"
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
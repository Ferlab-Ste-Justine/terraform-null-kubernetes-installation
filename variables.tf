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

variable "bastion_ip" {
    description = "Ip of the bastion"
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

variable "dependencies" {
    description = "Any dependencies that are not explicitly provided by the arguments, such as the bastion"
    type = any
}
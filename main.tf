resource "null_resource" "kubernetes_installation" {
  #If any machine in the cluster or the api external ip has changed, we need to re-provision
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
    load_balancer_ips = join(",", var.load_balancer_ips)
    version = var.revision
  }

  connection {
    host        = var.bastion_external_ip
    type        = "ssh"
    user        = var.bastion_user
    port        = var.bastion_port
    private_key = var.bastion_key_pair.private_key
  }

  #Ensure that cloud-init has finished running on the bastion as we require it to run ansible
  #Then, run ansible playbook to ensure cloud init has finished running without errors on all the dependencies
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "mkdir -p ${var.cloud_init_sync_path}"
    ]
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/sync-with-cloud-init/inventory", 
      {
        dependent_ips = concat(var.master_ips, var.worker_ips, var.wait_on_ips)
      }
    )
    destination = "${var.cloud_init_sync_path}/inventory"
  }  
  
  provisioner "file" {
    source      = "${path.module}/sync-with-cloud-init/sync.yml"
    destination = "${var.cloud_init_sync_path}/sync.yml"
  }

  provisioner "file" {
    source      = "${path.module}/sync-with-cloud-init/ansible.cfg"
    destination = "${var.cloud_init_sync_path}/ansible.cfg"
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "sudo docker run --rm -t --mount type=bind,src=${var.cloud_init_sync_path},dst=${var.cloud_init_sync_path} --mount type=bind,src=/home/${var.bastion_user}/.ssh/id_rsa,dst=/home/${var.bastion_user}/.ssh/id_rsa -e ANSIBLE_HOST_KEY_CHECKING=False -e ANSIBLE_CONFIG=${var.cloud_init_sync_path}/ansible.cfg ${var.kubespray_image} ansible-playbook --timeout=300 --private-key=/home/${var.bastion_user}/.ssh/id_rsa --user ${var.k8_cluster_user} --inventory ${var.cloud_init_sync_path}/inventory --become --become-user=root ${var.cloud_init_sync_path}/sync.yml",
      #cleanup
      "sudo rm -r ${var.cloud_init_sync_path}"
    ]
  }

  #Upload the ca certificates and keys on the masters
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.certificates_path}/certs"
    ]
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/upload-ca-certificates/inventory", 
      {
        master_ips = var.master_ips
      }
    )
    destination = "${var.certificates_path}/inventory"
  }  
  
  provisioner "file" {
    source      = "${path.module}/upload-ca-certificates/upload.yml"
    destination = "${var.certificates_path}/upload.yml"
  }

  provisioner "file" {
    source      = "${path.module}/upload-ca-certificates/ansible.cfg"
    destination = "${var.certificates_path}/ansible.cfg"
  }

  provisioner "file" {
    content     = var.ca_certificate != "" ? var.ca_certificate : "N/A"
    destination = "${var.certificates_path}/certs/ca.crt"
  }

  provisioner "file" {
    content     = var.ca_private_key != "" ? var.ca_private_key : "N/A"
    destination = "${var.certificates_path}/certs/ca.key"
  }

  provisioner "file" {
    content     = var.etcd_ca_certificate != "" ? var.etcd_ca_certificate : "N/A"
    destination = "${var.certificates_path}/certs/etcd.crt"
  }

  provisioner "file" {
    content     = var.etcd_ca_private_key != "" ? var.etcd_ca_private_key : "N/A"
    destination = "${var.certificates_path}/certs/etcd.key"
  }

  provisioner "file" {
    content     = var.front_proxy_ca_certificate != "" ? var.front_proxy_ca_certificate : "N/A"
    destination = "${var.certificates_path}/certs/front-proxy.crt"
  }

  provisioner "file" {
    content     = var.front_proxy_ca_private_key != "" ? var.front_proxy_ca_private_key : "N/A"
    destination = "${var.certificates_path}/certs/front-proxy.key"
  }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      var.ca_certificate != "" ? "sudo docker run --rm -t --mount type=bind,src=${var.certificates_path},dst=${var.certificates_path} --mount type=bind,src=/home/${var.bastion_user}/.ssh/id_rsa,dst=/home/${var.bastion_user}/.ssh/id_rsa -e ANSIBLE_HOST_KEY_CHECKING=False -e ANSIBLE_CONFIG=${var.certificates_path}/ansible.cfg ${var.kubespray_image} ansible-playbook --private-key=/home/${var.bastion_user}/.ssh/id_rsa --user ${var.k8_cluster_user} --inventory ${var.certificates_path}/inventory --become --become-user=root ${var.certificates_path}/upload.yml" : ":",
      #cleanup
      "sudo rm -r ${var.certificates_path}"
    ]
  }

  #Clone and prepup kubespray on a stable branch
  provisioner "remote-exec" {
    inline = [
        "set -o errexit",
        "git clone ${var.kubespray_repo} ${var.provisioning_path}",
        "cd ${var.provisioning_path} && git checkout ${var.kubespray_repo_ref}",
        "cd ${var.provisioning_path} && cp -rfp inventory/sample inventory/deployment"
    ]
  }

  #Copy our custom configuration, inventory and run kubespray
  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/etcd.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/etcd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/all.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/all.yml"
  }

  provisioner "file" {
    content      = templatefile(
      "${path.module}/kubespray/configurations/all/containerd.yml",
      {
        container_registry_credentials = var.container_registry_credentials
      }
    )
    destination  = "${var.provisioning_path}/inventory/deployment/group_vars/all/containerd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/docker.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/docker.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/etcd.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/etcd.yml"
  }

  provisioner "file" {
    content      = templatefile(
      "${path.module}/kubespray/configurations/all/offline.yml",
      {
        custom_container_repos = var.custom_container_repos
      }
    )
    destination  = "${var.provisioning_path}/inventory/deployment/group_vars/all/offline.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/openstack.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/openstack.yml"
  }

  provisioner "file" {
    content      = templatefile(
      "${path.module}/kubespray/configurations/k8s_cluster/addons.yml",
      {
        ingress_http_port = var.k8_ingress_http_port
        ingress_https_port = var.k8_ingress_https_port
        ingress_arguments = var.ingress_arguments
      }
    )
    destination  = "${var.provisioning_path}/inventory/deployment/group_vars/k8s_cluster/addons.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/configurations/k8s_cluster/k8s-cluster.yml", 
      {
        cluster_name = var.k8_cluster_name
        artifacts_dir = var.artifacts_path
        load_balancer_ips = var.load_balancer_ips
        kubernetes_version = var.k8_version
      }
    )
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s_cluster/k8s-cluster.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/configurations/k8s_cluster/k8s-net-calico.yml", 
      {
        calico = var.calico
      }
    )
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s_cluster/k8s-net-calico.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s_cluster/k8s-net-flannel.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s_cluster/k8s-net-flannel.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/inventory", 
      {
        master_ips = var.master_ips, 
        worker_ips = var.worker_ips
      }
    )
    destination = "${var.provisioning_path}/inventory/deployment/inventory"
  }

  provisioner "remote-exec" {
      inline = [
          "set -o errexit",
          "if [ -d "${var.artifacts_path}" ]; then rm -Rf ${var.artifacts_path}; fi",
          "mkdir -p ${var.artifacts_path}",
          "sudo docker run --rm -t --mount type=bind,src=${var.provisioning_path},dst=${var.provisioning_path} --mount type=bind,src=${var.artifacts_path},dst=${var.artifacts_path} --mount type=bind,src=/home/${var.bastion_user}/.ssh/id_rsa,dst=/home/${var.bastion_user}/.ssh/id_rsa -e ANSIBLE_HOST_KEY_CHECKING=False ${var.kubespray_image} ansible-playbook --private-key=/home/${var.bastion_user}/.ssh/id_rsa --user ${var.k8_cluster_user} --inventory ${var.provisioning_path}/inventory/deployment/inventory --become --become-user=root ${var.provisioning_path}/cluster.yml",
          "sudo chown -R $(id -u):$(id -g) ${var.artifacts_path}",
          #cleanup
          "sudo rm -r ${var.provisioning_path}"
      ]
  }
}
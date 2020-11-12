locals {
  kubespray_tag = "v2.14.2"
}

resource "null_resource" "kubernetes_installation" {
  #If any machine in the cluster or the api external ip has changed, we need to re-provision
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
    load_balancer_external_ip = var.load_balancer_external_ip
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
      "ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=${var.cloud_init_sync_path}/ansible.cfg ansible-playbook --private-key=/home/${var.bastion_user}/.ssh/id_rsa --user ${var.k8_cluster_user} --inventory ${var.cloud_init_sync_path}/inventory --become --become-user=root ${var.cloud_init_sync_path}/sync.yml",
      "sudo rm -r ${var.cloud_init_sync_path}"
    ]
  }

  #Clone and prepup kubespray on a stable branch
  provisioner "remote-exec" {
    inline = [
        "git clone https://github.com/kubernetes-sigs/kubespray.git ${var.provisioning_path}",
        "mkdir -p ${var.artifacts_path}",
        "cd ${var.provisioning_path} && git checkout ${local.kubespray_tag}",
        "cd ${var.provisioning_path} && sudo pip3 install -r requirements.txt",
        "cd ${var.provisioning_path} && cp -rfp inventory/sample inventory/deployment",
        #Also, add custom addons directory for addons not managed by kubespray
        "mkdir -p ${var.provisioning_path}/custom_addons/cert-manager"
    ]
  }

  #Copy custom addon files
  provisioner "file" {
    source      = "${path.module}/addons/cert-manager/cert-manager.yaml"
    destination = "${var.provisioning_path}/custom_addons/cert-manager/cert-manager.yaml"
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
    source      = "${path.module}/kubespray/configurations/all/containerd.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/containerd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/docker.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/docker.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/openstack.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/all/openstack.yml"
  }

  provisioner "file" {
    content      = templatefile(
      "${path.module}/kubespray/configurations/k8s-cluster/addons.yml",
      {
        ingress_http_port = var.k8_ingress_http_port
        ingress_https_port = var.k8_ingress_https_port
      }
    )
    destination  = "${var.provisioning_path}/inventory/deployment/group_vars/k8s-cluster/addons.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/configurations/k8s-cluster/k8s-cluster.yml", 
      {
        cluster_name = var.k8_cluster_name
        artifacts_dir = var.artifacts_path
        load_balancer_external_ip = var.load_balancer_external_ip
        kubernetes_version = var.k8_version
      }
    )
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s-cluster/k8s-cluster.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s-cluster/k8s-net-calico.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-calico.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s-cluster/k8s-net-flannel.yml"
    destination = "${var.provisioning_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-flannel.yml"
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
          "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=/home/${var.bastion_user}/.ssh/id_rsa --user ${var.k8_cluster_user} --inventory ${var.provisioning_path}/inventory/deployment/inventory --become --become-user=root ${var.provisioning_path}/cluster.yml",
          #Unless we force kubespray to use our external api load balancer internally, it will make the kubectl configuration point to the internal ip of the first master
          #To save ourselves an edit downstream, we automatically change it to the external load balancer ip so that the configuration file is both robust and usable anywhere
          "cp ${var.artifacts_path}/admin.conf ${var.artifacts_path}/admin-external.conf",
          "sed -i -E \"s/server: https:\\/\\/[0-9]+.[0-9]+.[0-9]+.[0-9]+:6443/server: https:\\/\\/${var.load_balancer_external_ip}:6443/\" ${var.artifacts_path}/admin-external.conf",
          #Add a recent version of cert-manager
          "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply -f ${var.provisioning_path}/custom_addons/cert-manager/cert-manager.yaml",
          #cleanup
          "sudo rm -r ${var.provisioning_path}"
      ]
  }
}
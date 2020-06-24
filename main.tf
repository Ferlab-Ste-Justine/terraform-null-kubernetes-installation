resource "null_resource" "kubernetes_installation" {
  #If any machine in the cluster or the api external ip has changed, we need to re-provision
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
    load_balancer_external_ip = var.load_balancer_external_ip
  }

  connection {
    host        = var.bastion_external_ip
    type        = "ssh"
    user        = "ubuntu"
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
  
  provisioner "remote-exec" {
    inline = [
      "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=/home/ubuntu/.ssh/id_rsa --user ubuntu --inventory ${var.cloud_init_sync_path}/inventory --become --become-user=root ${var.cloud_init_sync_path}/sync.yml",
      "sudo rm -r ${var.cloud_init_sync_path}"
    ]
  }

  #Clone and prepup kubespray on a stable branch
  provisioner "remote-exec" {
    inline = [
        "git clone https://github.com/kubernetes-sigs/kubespray.git ${var.kubespray_path}",
        "cd ${var.kubespray_path} && git checkout v2.13.2",
        "cd ${var.kubespray_path} && sudo pip3 install -r requirements.txt",
        "cd ${var.kubespray_path} && cp -rfp inventory/sample inventory/deployment",
    ]
  }

  #Copy our custom configuration, inventory and run kubespray
  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/etcd.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/etcd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/all.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/all.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/containerd.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/containerd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/docker.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/docker.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/all/openstack.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/openstack.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s-cluster/addons.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/addons.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/configurations/k8s-cluster/k8s-cluster.yml", 
      {
        load_balancer_external_ip = var.load_balancer_external_ip
      }
    )
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-cluster.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s-cluster/k8s-net-calico.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-calico.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray/configurations/k8s-cluster/k8s-net-flannel.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-flannel.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray/inventory", 
      {
        master_ips = var.master_ips, 
        worker_ips = var.worker_ips
      }
    )
    destination = "${var.kubespray_path}/inventory/deployment/inventory"
  }

  provisioner "remote-exec" {
      inline = [
          "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=/home/ubuntu/.ssh/id_rsa --user ubuntu --inventory ${var.kubespray_path}/inventory/deployment/inventory --become --become-user=root ${var.kubespray_path}/cluster.yml",
          "sudo rm -r ${var.kubespray_path}"
      ]
  }
}
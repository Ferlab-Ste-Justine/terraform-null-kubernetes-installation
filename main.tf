resource "null_resource" "kubernetes_installation" {
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
    load_balancer_external_ip = var.load_balancer_external_ip
  }

  connection {
    host        = var.bastion_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.bastion_key_pair.private_key
  }

  provisioner "remote-exec" {
      inline = [
          "git clone https://github.com/kubernetes-sigs/kubespray.git ${var.kubespray_path}",
          "cd ${var.kubespray_path} && git checkout v2.13.2",
          "cd ${var.kubespray_path} && sudo pip3 install -r requirements.txt",
          "cd ${var.kubespray_path} && cp -rfp inventory/sample inventory/deployment",
      ]
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/etcd.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/etcd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/all/all.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/all.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/all/containerd.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/containerd.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/all/docker.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/docker.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/all/openstack.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/all/openstack.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/k8s-cluster/addons.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/addons.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/kubespray_configurations/k8s-cluster/k8s-cluster.yml", 
      {
        load_balancer_external_ip = var.load_balancer_external_ip
      }
    )
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-cluster.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/k8s-cluster/k8s-net-calico.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-calico.yml"
  }

  provisioner "file" {
    source      = "${path.module}/kubespray_configurations/k8s-cluster/k8s-net-flannel.yml"
    destination = "${var.kubespray_path}/inventory/deployment/group_vars/k8s-cluster/k8s-net-flannel.yml"
  }

  provisioner "file" {
    content     = templatefile(
      "${path.module}/templates/inventory.ini", 
      {
        master_ips = var.master_ips, 
        worker_ips = var.worker_ips
      }
    )
    destination = "${var.kubespray_path}/inventory/deployment/inventory.ini"
  }

  provisioner "remote-exec" {
      inline = [
          "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=/home/ubuntu/.ssh/id_rsa --user ubuntu --inventory ${var.kubespray_path}/inventory/deployment/inventory.ini --become --become-user=root ${var.kubespray_path}/cluster.yml",
          "sudo rm -r ${var.kubespray_path}"
      ]
  }
}
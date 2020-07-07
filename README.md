# About

This is a terraform module to install kubernetes on a a bunch of master and worker nodes. The presence of a bastion with ansible installed is presumed.

Currently, the module uses kubespray underneat the hood to achieve this and, subject to the limitations of kubespray, should be idempotent.

Prior to running the kubernetes installation, the module will wait for cloud-init to run on all involved node.

Furthermore, a configuration file for kubectl and a kubectl binary with the appropriate version will be downloaded in the bastion.

# Input Variables

The module takes the following input variables:

- master_ips: The ips of the master nodes
- worker_ips: The ips of the worker nodes
- load_balancer_external_ip: External load-balancing ip of the master apis. Will be added to the kubernetes certificate.
- bastion_external_ip: Ip of the bastion host that will be sshed on. It is assumed to have ssh access to all the master and worker nodes.
- bastion_port: Port that the bastion will be sshed on. Defaults to **22**.
- bastion_user: User that will be used to ssh on the bastion. Defaults to **ubuntu**.
- k8_cluster_user: User that the bastion will use to ssh to machines on the kuberntes cluster
- bastion_key_pair: Ssh key that will be used to ssh on the bastion
- provisioning_path: Path on the bastion that will be used to copy playbooks and kubespray configuration for provisionning. Will be deleted at the end of the installation.
- artifacts_path: Path on the bastion where the kubectl binary and admin configuration files will be downloaded.
- cloud_init_sync_path: Path on the bastion to copy playbooks to wait for cloud-init to finish. Will be deleted after the wait is over.
- bastion_dependent_ip: Placeholder variable to pass the internal ip of the bastion. Useful to force terraform to wait until the bastion is provisioned before launching this module. The variable is not used otherwise.
- wait_on_ips: Ip of additional vms to wait for (ex: load balancer) before launching the installation.
- revision: Internal variable used to trigger a reprovisioning of the installation when the module changes. Can be used externally (ideally only in cases of an emergency) to explicitly force a re-installation (by passing the date and time as a value for example). Such explicit retriggerings should obviously be commited in version control to keep an audit of all impacting actions on shared environments.

# Output Variables

The module generates the following output variables:

- id: Unique id produced as a result of the installation. Should be used by downstream dependencies to wait for the installation to finish and trigger reprovisioning when the installation changes.
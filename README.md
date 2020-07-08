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
- k8_ingress_http_port: Port on the kubernetes workers that will be used for ingress http traffic
- k8_ingress_https_port: Port on the kubernetes workers that will be used for ingress https traffic

# Output Variables

The module generates the following output variables:

- id: Unique id produced as a result of the installation. Should be used by downstream dependencies to wait for the installation to finish and trigger reprovisioning when the installation changes.

# Notes

## Ingress

The reference installation of nginx ingress for non-public clouds use a deployment and nodeport service (with several gotchas).

The kubespray installation of nginx ingress uses a daemonset with ports mapped on the host. This is the one we will be using for now.

This probably works around the first gotcha (where you need to make the nodeport route locally on each node and ensure to have a controller pod running on each node not to drop traffic, all in order to preserve the source ip). Not sure about the second gotcha (about ingress object status not updating, that part of the ingress documentation is still rather vague for the author of this README).

If we experience issues in the future, it may be worthwhile to turn the ingress addon off in the kubespray config and instead install the nginx ingress separately using a custom adaptation on the reference installation.

Either way, our foreseen reliance on the ingress controller (only as a dependency for cert-manager to create routes for the acme challenge when creating/renewing certificates) is very low, so there may be some issues that would arise with more advance usages that we will never bump into.

Links of relevance for this note:
- https://kubernetes.github.io/ingress-nginx/deploy/baremetal/
- https://github.com/kubernetes-sigs/kubespray/blob/master/roles/kubernetes-apps/ingress_controller/ingress_nginx/templates/ds-ingress-nginx-controller.yml.j2
- https://github.com/kubernetes/ingress-nginx/blob/master/deploy/static/provider/baremetal/deploy.yaml
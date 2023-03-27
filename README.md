# About

This is a terraform module to install kubernetes on a a bunch of master and worker nodes. The presence of a bastion with docker installed is presumed.

Currently, the module uses kubespray underneat the hood to achieve this and, subject to the limitations of kubespray, should be idempotent.

Prior to running the kubernetes installation, the module will wait for cloud-init to run on all involved node.

# Input Variables

The module takes the following input variables:

- **master_ips**: The ips of the master nodes
- **worker_ips**: The ips of the worker nodes
- **load_balancer_ips**: Load-balancing ips of the master apis. Will be added to the kubernetes certificate.
- **bastion_external_ip**: Ip of the bastion host that will be sshed on. It is assumed to have ssh access to all the master and worker nodes.
- **bastion_port**: Port that the bastion will be sshed on. Defaults to **22**.
- **bastion_user**: User that will be used to ssh on the bastion. Defaults to **ubuntu**.
- **k8_cluster_user**: User that the bastion will use to ssh to machines on the kuberntes cluster
- **bastion_key_pair**: Ssh key that will be used to ssh on the bastion
- **provisioning_path**: Path on the bastion that will be used to copy playbooks and kubespray configuration for provisionning. Will be deleted at the end of the installation.
- **artifacts_path**: Path on the bastion where the kubectl binary and admin configuration files will be downloaded.
- **cloud_init_sync_path**: Path on the bastion to copy playbooks to wait for cloud-init to finish. Will be deleted after the wait is over.
- **certificates_path**: Path on the bastion to upload optional user-provided private keys and certificates that will be uploaded on the kubernetes api servers. Will be deleted after the files are uploaded on the api servers.
- **bastion_dependent_ip**: Placeholder variable to pass the internal ip of the bastion. Useful to force terraform to wait until the bastion is provisioned before launching this module. The variable is not used otherwise.
- **wait_on_ips**: Ip of additional vms to wait for (ex: load balancer) before launching the installation.
- **revision**: Internal variable used to trigger a reprovisioning of the installation when the module changes. Can be used externally (ideally only in cases of an emergency) to explicitly force a re-installation (by passing the date and time as a value for example). Such explicit retriggerings should obviously be commited in version control to keep an audit of all impacting actions on shared environments.
- **k8_ingress_http_port**: Port on the kubernetes workers that will be used for ingress http traffic
- **k8_ingress_https_port**: Port on the kubernetes workers that will be used for ingress https traffic
- **k8_cluster_name**: Name of the kubernetes cluster. Mostly relevant if you want to reference multiple kubernetes clusters with the same configuration file. Defaullts to **cluster.local**
- **k8_version**: Version of kubernetes to install. Defaults to **v1.25.6**.
- **custom_container_repos**: Non-default container repos. Image names can be left with the empty string to go with the default.
  - **enabled**: If set to false (the default), no custom container repos will be used.
  - **registry**: Registry name with the namespace (or account).
  - **image_names**: Image names.
    - **coredns**: CoreDNS image name.
    - **dnsautoscaler**: DNS-Autoscaler image name.
    - **ingress_nginx_controller**: NGINX-Ingress-Controller image name.
    - **nodelocaldns**: NodeLocal-DNSCache image name.
    - **pause**: Pause image name.
- **kubespray_repo**: Repository to clone kubespray from. Defaults to the official repository.
- **kubespray_repo_ref**: Tag or branch to use in the repo before running the kubespray playbooks. The default is the tag **v2.21.0** which is the tag the custom configuration of this repo is adapted to. You may not be successful if you use another tag/branch with different configuration expectations.
- **kubespray_image**: Docker image to use for running the kubespray playbooks. The default is **ferlabcrsj/kubespray:2.21.0** which correlates with the value of **kubespray_repo_ref**.
- **ingress_arguments**: Extra arguments to pass to ingress-nginx (ex: **--enable-ssl-passthrough**).

## User Provided Certificates Variables

By default, kubespray will generate the private keys are certificates for the internal certificate authorities of kubernetes.

However, if the user wishes, he can pass his own ca certificates and private keys (see following repo for an implementation: https://github.com/Ferlab-Ste-Justine/kubernetes-certificates).

They can be passed through the following optional input variables (not that you must provide a valid input for ALL of these variables if you wish to use them):

- ca_certificate: Certificate of the main ca.
- ca_private_key: Private key of the main ca.
- etcd_ca_certificate: Certificate of the etcd ca.
- etcd_ca_private_key: Private key of the etcd ca.
- front_proxy_ca_certificate: Certificate of the front proxy ca.
- front_proxy_ca_private_key: Private key of the front proxy ca.

# Output Variables

The module generates the following output variables:

- id: Unique id produced as a result of the installation. Should be used by downstream dependencies to wait for the installation to finish and trigger reprovisioning when the installation changes.
TERRAFORM=tofu -chdir=terraform
TALOSCONFIG=./generated/talosconfig

include_env_vars:
	@[ -f ../.envrc ] && set -a && . ../.envrc && set +a
	export PROXMOX_VE_ENDPOINT=https://${PROXMOX_NODE_TWO_IP}:8006
	export PROXMOX_VE_API_TOKEN=${PROXMOX_NODE_TWO_API_TOKEN}

init:
	$(TERRAFORM) init --upgrade

plan: include_env_vars
	$(TERRAFORM) plan \
		-var k8s_api_server_ip=${MASTER_NODE_IP} \
		-var network_gateway=${PROXMOX_NETWORK_GATEWAY} \
    -var master_node_ip=${MASTER_NODE_IP} \
    -var worker_one_node_ip=${WORKER_00_NODE_IP} \
    -var worker_two_node_ip=${WORKER_01_NODE_IP} \
		-var proxmox_server_ip=${PROXMOX_NODE_TWO_IP} \
		-var proxmox_username=${PROXMOX_USERNAME} \
		-var proxmox_password=${PROXMOX_PASSWORD} \
		-var proxmox_ssh_private_key=${PROXMOX_NODE_TWO_PRIVATE_KEY} \
		-var proxmox_api_token=${PROXMOX_NODE_TWO_API_TOKEN}

apply: include_env_vars
	$(TERRAFORM) apply -auto-approve \
		-var k8s_api_server_ip=${MASTER_NODE_IP} \
		-var network_gateway=${PROXMOX_NETWORK_GATEWAY} \
    -var master_node_ip=${MASTER_NODE_IP} \
    -var worker_one_node_ip=${WORKER_00_NODE_IP} \
    -var worker_two_node_ip=${WORKER_01_NODE_IP} \
		-var proxmox_server_ip=${PROXMOX_NODE_TWO_IP} \
		-var proxmox_username=${PROXMOX_USERNAME} \
		-var proxmox_password=${PROXMOX_PASSWORD} \
		-var proxmox_ssh_private_key=${PROXMOX_NODE_TWO_PRIVATE_KEY} \
		-var proxmox_api_token=${PROXMOX_NODE_TWO_API_TOKEN}

tf_run: init plan apply

tf_destroy: include_env_vars init
	$(TERRAFORM) destroy -auto-approve \
		-var k8s_api_server_ip=${MASTER_NODE_IP} \
		-var network_gateway=${PROXMOX_NETWORK_GATEWAY} \
    -var master_node_ip=${MASTER_NODE_IP} \
    -var worker_one_node_ip=${WORKER_00_NODE_IP} \
    -var worker_two_node_ip=${WORKER_01_NODE_IP} \
		-var proxmox_server_ip=${PROXMOX_NODE_TWO_IP} \
		-var proxmox_username=${PROXMOX_USERNAME} \
		-var proxmox_password=${PROXMOX_PASSWORD} \
		-var proxmox_ssh_private_key=${PROXMOX_NODE_TWO_PRIVATE_KEY} \
		-var proxmox_api_token=${PROXMOX_NODE_TWO_API_TOKEN}

helmfile_apply:
	helmfile apply --skip-diff-on-install --suppress-diff .

helmfile_sync:
	helmfile sync  .

helmfile_lock:
	helmfile deps

clean:
	rm -rf .task
	rm -rf terraform/.terraform
	rm -rf terraform/terraform.tfstate
	rm -rf terraform/terraform.tfstate.backup
	rm -rf terraform/.terraform.lock.hcl

reboot-node:
	talosctl reboot --nodes $(NODE)
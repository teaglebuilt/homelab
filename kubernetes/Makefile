TERRAFORM=tofu -chdir=terraform
TALOSCONFIG=./generated/talosconfig

include_env_vars:
	@[ -f ../.envrc ] && set -a && . ../.envrc && set +a

init:
	$(TERRAFORM) init --upgrade

plan: include_env_vars
	$(TERRAFORM) plan \
		-var k8s_api_server_ip=${MASTER_NODE_IP} \
		-var network_gateway=${PROXMOX_NETWORK_GATEWAY} \
    -var master_node_ip=${MASTER_NODE_IP} \
    -var worker_one_node_ip=${WORKER_00_NODE_IP} \
    -var worker_two_node_ip=${WORKER_01_NODE_IP}

apply: include_env_vars
	$(TERRAFORM) apply -auto-approve \
		-var k8s_api_server_ip=${MASTER_NODE_IP} \
		-var network_gateway=${PROXMOX_NETWORK_GATEWAY} \
    -var master_node_ip=${MASTER_NODE_IP} \
    -var worker_one_node_ip=${WORKER_00_NODE_IP} \
    -var worker_two_node_ip=${WORKER_01_NODE_IP}

tf_run: init plan apply

tf_destroy:
	$(TERRAFORM) destroy -auto-approve

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
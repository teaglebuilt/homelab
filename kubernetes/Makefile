TERRAFORM=tofu -chdir=terraform
TALOSCONFIG=./generated/talosconfig

include_env_vars:
	@[ -f ../.envrc ] && set -a && . ../.envrc && set +a

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

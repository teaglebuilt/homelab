TERRAFORM=tofu -chdir=terraform
TALOSCONFIG=./generated/talosconfig

include_env_vars:
	@[ -f .env ] && set -a && . ./.env && set +a

init:
	$(TERRAFORM) init --upgrade

plan: include_env_vars
	$(TERRAFORM) plan --var-file=terraform.tfvars

apply: include_env_vars
	$(TERRAFORM) apply --var-file=terraform.tfvars -auto-approve

tf_run: include_env_vars init plan apply

tf_destroy:
	$(TERRAFORM) destroy -auto-approve

helmfile_apply:
	helmfile apply --skip-diff-on-install --suppress-diff .

clean:
	rm -rf .task
	rm -rf terraform/.terraform
	rm -rf terraform/terraform.tfstate
	rm -rf terraform/terraform.tfstate.backup
	rm -rf terraform/.terraform.lock.hcl

reboot-node:
	talosctl reboot --nodes $(NODE)
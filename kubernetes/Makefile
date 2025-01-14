TERRAFORM=tofu -chdir=terraform

include_env_vars:
	@[ -f .env ] && set -a && . ./.env && set +a

init:
	$(TERRAFORM) init

plan:
	$(TERRAFORM) plan

apply:
	$(TERRAFORM) apply -auto-approve \
		-var-file=terraform.tfvars

tf_run: include_env_vars init plan apply

tf_destroy:
	$(TERRAFORM) destroy -auto-approve
TERRAFORM=terraform -chdir=terraform

init:
	$(TERRAFORM) init

plan:
	$(TERRAFORM) plan

apply:
	$(TERRAFORM) apply -auto-approve \
		-var-file=terraform.tfvars

tf_run: init plan apply


bootstrap:
	task setup_kubernetes_cluster:
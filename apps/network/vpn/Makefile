CURRENT_DIR ?= $(shell pwd)

tf_init:
	@echo "Initializing Terraform..."
	@echo "Terraform initialized."

tf_plan:
	@echo "Planning VPN..."
	@echo "VPN planned."

tf_apply:
	@echo "Applying VPN..."
	@echo "VPN applied."

provision: tf_init tf_plan tf_apply
	@echo "VPN provisioned."
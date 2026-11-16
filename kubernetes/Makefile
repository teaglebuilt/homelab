TERRAFORM=tofu -chdir=terraform/{cluster}
TALOSCONFIG=./generated/{cluster}/talosconfig

include_env_vars:
	@[ -f ../.envrc ] && set -a && . ../.envrc && set +a

helmfile_apply: include_env_vars
	helmfile apply --skip-diff-on-install --suppress-diff .

helmfile_sync_application:
	helmfile -f clusters/application/helmfile.yaml sync

helmfile_sync_mlops:
	helmfile -f clusters/mlops/helmfile.yaml sync

# Run deps through each cluster entrypoint so 01-bootstrap receives meshOverlay
# (and identityOverlay). Bare `helmfile deps` loads helmfile.d/ directly, which
# trips the ClusterMesh guard when enable.clusterMesh=true.
helmfile_lock: build_chart_dependencies
	helmfile -f clusters/mlops/helmfile.yaml deps
	helmfile -f clusters/application/helmfile.yaml deps


clean:
	rm -rf .task
	rm -rf terraform/.terraform
	rm -rf terraform/terraform.tfstate
	rm -rf terraform/terraform.tfstate.backup
	rm -rf terraform/.terraform.lock.hcl

reboot-node:
	talosctl reboot --nodes $(NODE)

build_chart_dependencies:
	helm dependency update ./charts/homelab-gateway
	helm dependency build ./charts/homelab-gateway

deploy:
	sops -d -i k8s/secrets.sops.yaml
	kustomize build --enable-helm --enable-exec ./k8s | kubectl apply -f -
	sops -e -i k8s/secrets.sops.yaml

destroy:
	kustomize build ./k8s --enable-helm --enable-exec | kubectl delete -f -
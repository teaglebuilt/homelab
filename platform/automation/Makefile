

deploy:
	kustomize build --enable-exec k8s | kubectl apply -f -

destroy:
	kustomize build --enable-exec k8s | kubectl delete -f -
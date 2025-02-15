
deploy:
	kustomize build ./k8s --enable-helm --enable-exec | kubectl apply -f -

destroy:
	kustomize build ./k8s --enable-helm --enable-exec | kubectl delete -f -
import subprocess


def test_kube_api_server_access():
    talos_deployment = subprocess.call("talosctl inject serviceaccount -f deployment.yaml > deployment-injected.yaml")
    subprocess.call("kubectl apply -n default -f deployment-injected.yaml")
    output = subprocess.call("kubectl logs -n default -f -l app=talos-kube-api-access")
    assert output is not None


def test_nvidia_extension():
    gpu_pods = subprocess.call("kubectl get pods -A -o wide | grep -E 'nvidia|cuda'")
    assert gpu_pods is not None

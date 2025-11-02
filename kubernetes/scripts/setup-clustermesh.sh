#!/bin/bash

# Cilium ClusterMesh Setup Script
# This script helps establish the ClusterMesh connection between clusters

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MLOPS_CONTEXT="${MLOPS_CONTEXT:-mlops}"
ADMIN_CONTEXT="${ADMIN_CONTEXT:-administration}"
CILIUM_VERSION="${CILIUM_VERSION:-1.17.3}"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Cilium CLI
install_cilium_cli() {
    print_info "Installing Cilium CLI..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        CLI_ARCH=amd64
        if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        CLI_ARCH=amd64
        if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
        shasum -a 256 -c cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
    else
        print_error "Unsupported OS type: $OSTYPE"
        exit 1
    fi

    print_info "Cilium CLI installed successfully"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check for kubectl
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi

    # Check for helmfile
    if ! command_exists helmfile; then
        print_error "helmfile is not installed. Please install helmfile first."
        exit 1
    fi

    # Check for Cilium CLI
    if ! command_exists cilium; then
        print_warning "Cilium CLI is not installed."
        read -p "Do you want to install it now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_cilium_cli
        else
            print_error "Cilium CLI is required for ClusterMesh setup."
            exit 1
        fi
    fi

    print_info "All prerequisites met"
}

# Deploy Cilium to cluster
deploy_cilium() {
    local context=$1
    local cluster_name=$2

    print_info "Deploying Cilium to $cluster_name cluster (context: $context)..."

    # Switch to cluster directory
    cd /Users/teaglebuilt/github/teaglebuilt/homelab/kubernetes/clusters/$cluster_name

    # Deploy using helmfile
    helmfile --kube-context=$context sync

    # Wait for Cilium to be ready
    print_info "Waiting for Cilium to be ready in $cluster_name..."
    kubectl --context=$context -n kube-system wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s

    # Verify Cilium status
    cilium --context=$context status --wait

    print_info "Cilium deployed successfully to $cluster_name"
}

# Enable ClusterMesh on a cluster
enable_clustermesh() {
    local context=$1
    local cluster_name=$2

    print_info "Enabling ClusterMesh on $cluster_name cluster..."

    # Enable ClusterMesh
    cilium --context=$context clustermesh enable --service-type LoadBalancer

    # Wait for ClusterMesh to be ready
    print_info "Waiting for ClusterMesh to be ready on $cluster_name..."
    cilium --context=$context clustermesh status --wait

    print_info "ClusterMesh enabled on $cluster_name"
}

# Connect two clusters
connect_clusters() {
    print_info "Connecting clusters..."

    # Generate the connection information from MLOps cluster
    print_info "Extracting connection information from MLOps cluster..."
    cilium --context=$MLOPS_CONTEXT clustermesh connect --context-name=$ADMIN_CONTEXT --destination-context=$ADMIN_CONTEXT

    # Verify connection
    print_info "Verifying ClusterMesh connection..."
    sleep 10  # Give it a moment to establish connection

    # Check status on both clusters
    print_info "ClusterMesh status on MLOps:"
    cilium --context=$MLOPS_CONTEXT clustermesh status

    print_info "ClusterMesh status on Administration:"
    cilium --context=$ADMIN_CONTEXT clustermesh status

    print_info "Clusters connected successfully!"
}

# Test cross-cluster connectivity
test_connectivity() {
    print_info "Testing cross-cluster connectivity..."

    # Run connectivity test
    cilium --context=$MLOPS_CONTEXT connectivity test --multi-cluster=$ADMIN_CONTEXT

    print_info "Connectivity test completed"
}

# Main execution
main() {
    echo "======================================"
    echo "Cilium ClusterMesh Setup Script"
    echo "======================================"
    echo

    # Check prerequisites
    check_prerequisites

    # Menu
    echo "Select an option:"
    echo "1) Full setup (deploy Cilium and connect clusters)"
    echo "2) Deploy Cilium to MLOps cluster only"
    echo "3) Deploy Cilium to Administration cluster only"
    echo "4) Enable ClusterMesh on both clusters"
    echo "5) Connect clusters (ClusterMesh must be already enabled)"
    echo "6) Test connectivity between clusters"
    echo "7) Show ClusterMesh status"
    read -p "Enter your choice (1-7): " choice

    case $choice in
        1)
            deploy_cilium "$MLOPS_CONTEXT" "mlops"
            deploy_cilium "$ADMIN_CONTEXT" "administration"
            enable_clustermesh "$MLOPS_CONTEXT" "mlops"
            enable_clustermesh "$ADMIN_CONTEXT" "administration"
            connect_clusters
            test_connectivity
            ;;
        2)
            deploy_cilium "$MLOPS_CONTEXT" "mlops"
            ;;
        3)
            deploy_cilium "$ADMIN_CONTEXT" "administration"
            ;;
        4)
            enable_clustermesh "$MLOPS_CONTEXT" "mlops"
            enable_clustermesh "$ADMIN_CONTEXT" "administration"
            ;;
        5)
            connect_clusters
            ;;
        6)
            test_connectivity
            ;;
        7)
            print_info "ClusterMesh status on MLOps:"
            cilium --context=$MLOPS_CONTEXT clustermesh status
            echo
            print_info "ClusterMesh status on Administration:"
            cilium --context=$ADMIN_CONTEXT clustermesh status
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    print_info "Operation completed successfully!"
}

# Run main function
main "$@"

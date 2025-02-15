#!/bin/bash

# Set namespace and service account name
NAMESPACE="kube-system"
SERVICE_ACCOUNT="coredns"

# Check if the service account exists
if kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "⚠️  CoreDNS Service Account ($SERVICE_ACCOUNT) exists. Deleting..."
  kubectl delete sa "$SERVICE_ACCOUNT" -n "$NAMESPACE"
  echo "✅ CoreDNS Service Account deleted successfully."
else
  echo "✅ CoreDNS Service Account does not exist. No action needed."
fi
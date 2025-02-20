#! /bin/bash

kubectl get secret homelab-ca-secret -n cert-manager -o jsonpath="{.data.ca\.crt}" | base64 --decode > homelab-ca.crt

## TODO: import and trust
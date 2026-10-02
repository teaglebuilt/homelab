# Provisioning Secrets and Talos Enhancements

When provisioning the homelab the `.envrc` should not be used to hold values like api keys. We want to prepare for upcoming work for revamping our provisioning process and moving to argocd soon. In the meantime, using taskfile, we want to pull secrets we need for provisioning from somewhere instead of leaving them in the .envrc file. We can keep the functions that are used to build values in that file but not more than that. I want to be able to keep it in source control (github).


1. Store secrets somewhere and use them where needed.
    - what will we use? bitwarden? ssm?
    - how should we do it?
2. Replace static ip addresses. Can we use dhcp|dns or something with talos config?

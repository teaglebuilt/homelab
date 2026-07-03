# Shared ClusterMesh trust anchor

Both clusters must sign their mesh certificates from **one shared CA** so their
Cilium identities trust each other. This directory holds that CA as a
SOPS-encrypted Kubernetes Secret, applied identically to `kube-system` in **both**
clusters before the Cilium release.

## Why a Secret manifest and NOT Helm `tls.ca.*` values

The repo `.sops.yaml` `encrypted_regex` only matches Secret fields
(`data|stringData|apiVersion|metadata|kind|type`). If the CA key were placed in a
plain Helm values file (`clustermesh.apiserver.tls.ca.key`), **SOPS would encrypt
nothing and the private key would be committed in cleartext.** So the CA is
delivered as a real `Secret` named `cilium-ca` — which Cilium reuses as its trust
anchor — and that manifest IS matched by the regex.

Also do NOT use `clustermesh.apiserver.tls.auto.method: helm`: it mints a
different CA per cluster and breaks mutual trust.

## Generate once

```bash
openssl req -x509 -new -nodes -newkey rsa:4096 -days 3650 \
  -keyout ca.key -out ca.crt -subj "/CN=Cilium CA"

kubectl create secret generic cilium-ca -n kube-system \
  --from-file=ca.crt=ca.crt --from-file=ca.key=ca.key \
  --dry-run=client -o yaml > cilium-ca.sops.yaml

sops -e -i cilium-ca.sops.yaml   # AWS-KMS, matches the kubernetes/* rule
rm ca.key ca.crt                 # never leave plaintext key material on disk
```

## Apply to BOTH clusters before Cilium

Decrypt and apply in a `00-prepare` step (or a Cilium `presync` hook) against
each cluster context:

```bash
sops -d clusters/_shared/cilium-ca.sops.yaml | kubectl apply -f -
```

Once present in both clusters, `clustermesh.apiserver.tls.authMode: cluster`
(set in each cluster's `clustermesh-values.yaml`) makes the operator sign all
mesh certs from this CA — no `cilium clustermesh` CLI, auto-renewing.

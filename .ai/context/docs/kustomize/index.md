# Kustomize - Kubernetes Configuration Management

Template-free configuration customization for Kubernetes. Used in this repo inside Helmfile hooks for post-install resources.

## Relevance to This Repo

- NOT used as a standalone deployment tool -- always invoked via Helmfile hooks
- Pattern: `kustomize build --enable-exec --enable-helm ../apps/<category>/<app> | kubectl apply -f -`
- Each app directory with a `kustomization.yaml` layers additional resources after its Helm release
- Used with `--enable-exec` and `--enable-helm` flags for plugin support
- Combined with `envsubst` for environment variable substitution in some cases

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- kustomization.yaml reference
- Overlay and patch strategies
- Generator and transformer plugins
- Integration with Helm (--enable-helm)
- Best practices for organizing bases and overlays

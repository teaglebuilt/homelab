# Cloudflare provider. Auth comes from the environment (already exported via the
# repo's direnv for external-dns):
#   CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL   (global key)   — or —   CLOUDFLARE_API_TOKEN
# No credentials are stored in this repo.
provider "cloudflare" {}

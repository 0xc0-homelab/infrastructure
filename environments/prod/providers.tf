# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN,
# never from this file: both are in Vault (ci/infrastructure/proxmox), read into
# the environment by scripts/tofu locally and by the tofu workflows in CI.
provider "proxmox" {}

# The API token comes from CLOUDFLARE_API_TOKEN, from Vault (ci/shared/cloudflare).
provider "cloudflare" {}

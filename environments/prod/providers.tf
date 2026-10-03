# PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN, from Vault
# (ci/infrastructure/proxmox).
provider "proxmox" {}

# CLOUDFLARE_API_TOKEN, from Vault (ci/shared/cloudflare).
provider "cloudflare" {}

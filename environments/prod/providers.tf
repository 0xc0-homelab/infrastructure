# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN,
# never from this file: secrets/tofu.sops.yaml locally, Actions secrets in CI.
provider "proxmox" {}

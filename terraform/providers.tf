terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.pve_endpoint
  insecure = true
  # Credentials via environment: PROXMOX_VE_USERNAME / PROXMOX_VE_API_TOKEN
}

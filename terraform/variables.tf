variable "pve_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://10.10.10.113:8006/"
}

variable "pve_username" {
  description = "Proxmox username (with realm)"
  type        = string
  default     = "root@pam"
}

variable "template_vmid" {
  description = "VMID of the base Ubuntu cloud-image template"
  type        = number
  default     = 911
}

variable "node_subnet" {
  description = "Subnet (CIDR) the nodes live in"
  type        = string
  default     = "10.10.10.0/22"
}

variable "gateway" {
  description = "Default gateway"
  type        = string
  default     = "10.10.10.1"
}

variable "nameservers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["10.10.10.1", "1.1.1.1"]
}

variable "ssh_public_key" {
  description = "SSH public key injected into the nodes"
  type        = string
}

variable "ci_user" {
  description = "Cloud-init user"
  type        = string
  default     = "ubuntu"
}

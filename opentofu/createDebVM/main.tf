terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">=2.9.11"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.50.201:8006/api2/json"
  pm_user         = "root@pam"
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "debian12_clone" {
  name        = "debian12-vm-${var.vmid}"
  target_node = "pve" # Adjust if needed
  clone       = "198"
  vmid        = var.vmid

  # Do NOT autostart
  autostart   = false

  # VM config
  cores       = 2
  memory      = 2048
  # Add further config as needed

  # Cloud init
  ipconfig0   = "ip=129.168.50.${var.vmid}/24,gw=192.168.50.1"
  ciuser      = "root"
  sshkeys     = "" # Optional, can specify your SSH keys here

  # Provisioner to run the remote script after creation (before start)
  provisioner "local-exec" {
    command = "curl https://raw.githubusercontent.com/JungleJM/proxmox-iac/refs/heads/main/init-packages.sh | bash"
  }
}

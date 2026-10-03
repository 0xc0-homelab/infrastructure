packer {
  required_version = "~> 1.16"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "1.2.4"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "1.1.6"
    }
  }
}

source "proxmox-clone" "rocky" {
  proxmox_url  = var.proxmox_url
  username     = var.proxmox_username
  token        = var.proxmox_token
  node         = var.node
  task_timeout = "10m"

  clone_vm   = "rocky-10-cloud"
  full_clone = true

  # 9100-9199. A rebuild deletes the old template first, freeing the ID.
  vm_id                = 9102
  vm_name              = "rocky-10-base"
  template_name        = "rocky-10-base"
  template_description = "Rocky Linux 10, the official cloud image with the homelab base role. Built by Packer from packer/rocky-10-base, commit ${var.commit}."

  # The same size as the runner build: dnf upgrades the whole image.
  cores = 2
  # Left as kvm64, Rocky 10's kernel never gets past GRUB.
  cpu_type        = "x86-64-v3"
  memory          = 2048
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true

  # Packer cannot set a VM's firewall options (docs/zones.md, Machines).
  network_adapters {
    bridge   = var.build_bridge
    model    = "virtio"
    firewall = false
  }

  # A fixed address: the build does not wait on the guest agent.
  cloud_init              = true
  cloud_init_storage_pool = "local"
  # Upgrading systemd and NetworkManager under Packer's wait on cloud-init
  # hangs it: the upgrade runs as its own provisioner below.
  cloud_init_disable_upgrade_packages = true
  ipconfig {
    ip      = var.build_ip
    gateway = var.build_gateway
  }
  nameserver = "1.1.1.1 1.0.0.1"

  communicator = "ssh"
  ssh_username = "rocky"
  ssh_host     = split("/", var.build_ip)[0]
  ssh_timeout  = "10m"
}

build {
  sources = ["source.proxmox-clone.rocky"]

  # Exit 2 is "done, with recoverable errors": not a failure.
  provisioner "shell" {
    inline = ["cloud-init status --wait --long || { rc=$?; [ $rc -eq 2 ] && exit 0; exit $rc; }"]
  }

  # Before the upgrade, so it runs on Rocky's CDN, not the slow mirror.
  provisioner "ansible" {
    playbook_file = "${path.root}/playbook.yml"
    user          = "rocky"
    use_proxy     = false
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../../ansible/ansible.cfg",
      "ANSIBLE_ROLES_PATH=${path.root}/../../ansible/roles",
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]
  }

  # The upstream image is only rebuilt now and then.
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["dnf -y upgrade"]
  }

  # Every clone must get its own identity and its own cloud-init run.
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "dnf clean all",
      "cloud-init clean --logs --seed",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
    ]
  }
}

# The base template the RKE2 nodes clone: the official Rocky Linux cloud image
# (rocky-10-cloud, imported raw by OpenTofu) with the base role baked in, the
# guest agent among it. Per-VM settings stay with cloud-init and Ansible.
#
# No VMID and no version: Proxmox assigns the VMID, and everything finds the
# template by name. CI deletes the previous one by name before building it
# again (scripts/delete-template).

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

  vm_name              = "rocky-10-base"
  template_name        = "rocky-10-base"
  template_description = "Rocky Linux 10, the official cloud image with the homelab base role. Built by Packer from packer/rocky-10-base, commit ${var.commit}."

  # The same size as the runner build: dnf upgrades the whole image.
  cores = 2
  # RHEL 10, and Rocky 10 with it, needs an x86-64-v3 CPU; left unset, Packer
  # uses kvm64 and the kernel never gets past GRUB.
  cpu_type        = "x86-64-v3"
  memory          = 2048
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true

  # Packer cannot set a VM's firewall options, so there is no zone filtering on
  # the build VM either way: see Machines in docs/zones.md.
  network_adapters {
    bridge   = var.build_bridge
    model    = "virtio"
    firewall = false
  }

  # Packer puts its throwaway SSH key into cloud-init. The address is fixed,
  # so the build does not wait on the guest agent.
  cloud_init              = true
  cloud_init_storage_pool = "local"
  # Proxmox's cloud-init upgrades every package on first boot, systemd and
  # NetworkManager included, while Packer is already connected and waiting on
  # cloud-init: the wait never returns. The upgrade runs as its own
  # provisioner below instead, once cloud-init is done.
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

  # Package installs must not race cloud-init. Exit 2 is "done, with recoverable errors"
  # (deprecation warnings, typically): shown in the log, and not a failure.
  provisioner "shell" {
    inline = ["cloud-init status --wait --long || { rc=$?; [ $rc -eq 2 ] && exit 0; exit $rc; }"]
  }

  # The template is baked up to date: the image is only rebuilt upstream now
  # and then.
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["dnf -y upgrade"]
  }

  # The baseline every VM needs: the guest agent, SSH hardening.
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

# The runner template: debian-13-base with the GitHub Actions runner baked in
# (the github_runner role's install entry point). What makes a VM a runner,
# the App key and the units, stays in Ansible: a secret baked into a template
# cannot be rotated.
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

source "proxmox-clone" "runner" {
  proxmox_url  = var.proxmox_url
  username     = var.proxmox_username
  token        = var.proxmox_token
  node         = var.node
  task_timeout = "10m"

  clone_vm   = "debian-13-base"
  full_clone = true

  # Packer's templates take 9100-9199 (the raw images, 9000-9099). The build
  # VM gets the ID and keeps it as the template; a rebuild deletes the old
  # template first, so the ID is free again.
  vm_id                = 9101
  vm_name              = "debian-13-runner"
  template_name        = "debian-13-runner"
  template_description = "Debian 13 base with the GitHub Actions runner. Built by Packer from packer/debian-13-runner, commit ${var.commit}."

  cores           = 2
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
  ipconfig {
    ip      = var.build_ip
    gateway = var.build_gateway
  }
  nameserver = "1.1.1.1 1.0.0.1"

  communicator = "ssh"
  ssh_username = "debian"
  ssh_host     = split("/", var.build_ip)[0]
  ssh_timeout  = "10m"
}

build {
  sources = ["source.proxmox-clone.runner"]

  # apt must not race cloud-init. Exit 2 is "done, with recoverable errors"
  # (deprecation warnings, typically): shown in the log, and not a failure.
  provisioner "shell" {
    inline = ["cloud-init status --wait --long || { rc=$?; [ $rc -eq 2 ] && exit 0; exit $rc; }"]
  }

  # The runner's install entry point. The base role is already in debian-13-base.
  provisioner "ansible" {
    playbook_file = "${path.root}/playbook.yml"
    user          = "debian"
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
      "apt-get clean",
      "cloud-init clean --logs --seed",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
    ]
  }
}

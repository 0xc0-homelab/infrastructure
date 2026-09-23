# The runner template: the Debian base with the runner baked in (the
# github_runner role's install entry point). What makes a VM a runner, the App
# key and the units, stays in Ansible: a secret baked into a template cannot be
# rotated.

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

  clone_vm_id = var.base_template_id
  full_clone  = true

  vm_id                = var.vm_id
  vm_name              = "debian-13-runner-${var.version}"
  template_name        = "debian-13-runner-${var.version}"
  template_description = "Debian 13 with the GitHub Actions runner baked in. Built by Packer from packer/debian-13-runner, version ${var.version}."

  cores           = 2
  memory          = 2048
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true

  # Packer cannot set a VM's firewall options, so there is no zone filtering on
  # the build VM either way: see build_vms in docs/zones.md.
  network_adapters {
    bridge   = var.build_bridge
    model    = "virtio"
    firewall = false
  }

  # Packer puts its throwaway SSH key into cloud-init. The address is fixed,
  # so the build does not wait on the guest agent, which the base lacks.
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

  # cloud-init installs nothing we need, but apt must not race it. Exit 2 is
  # "done, with recoverable errors" (deprecation warnings, typically): shown in
  # the log, and not a failure.
  provisioner "shell" {
    inline = ["cloud-init status --wait --long || { rc=$?; [ $rc -eq 2 ] && exit 0; exit $rc; }"]
  }

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

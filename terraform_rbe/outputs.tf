output "template_vmid" {
  value = proxmox_virtual_environment_vm.template_source.vm_id
}

output "rbe_worker_vmids" {
  value = proxmox_virtual_environment_vm.rbe_worker[*].vm_id
}

output "rbe_worker_names" {
  value = proxmox_virtual_environment_vm.rbe_worker[*].name
}

output "rbe_worker_ip" {
  value = proxmox_virtual_environment_vm.rbe_worker[*].ipv4_addresses
}

output "rbe_worker_mgmt_ip" {
  value = [for vm in proxmox_virtual_environment_vm.rbe_worker : vm.ipv4_addresses[1][0]]
}
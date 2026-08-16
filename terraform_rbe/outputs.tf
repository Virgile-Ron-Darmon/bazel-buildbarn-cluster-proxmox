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

# The monitoring UIs run on the master (rbe-worker-1) and are reachable at the
# stable secondary static IP pinned on its ens18 mgmt interface
# (master_mgmt_static_ip), not the DHCP-assigned address, so these URLs don't
# change with the lease. Ports are the Ansible defaults
# (group_vars/rbe_master.yml); if you override grafana_port/prometheus_port
# there, update these too.
output "grafana_url" {
  value = "http://${var.master_mgmt_static_ip}:3000"
}

output "prometheus_url" {
  value = "http://${var.master_mgmt_static_ip}:9090"
}
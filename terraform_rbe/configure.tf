# Step 3: bring up the cluster's addressing and deploy Buildbarn.
#
# The source VM is not represented here; it has its own single-host inventory
# (inventory_source.ini, see source.tf) and is never a cluster member.
#
# Addressing no longer requires a fleet-wide Ansible sweep. Every worker's
# ens19 MAC is set by Terraform at creation time (deploy.tf, local.worker_macs)
# to encode its static 10.50.x.x address. Only the master needs a direct,
# guest-agent-discovered touch: it gets pinned to 10.50.0.1 and starts the
# DHCP server that hands the rest of the fleet their addresses by MAC.

locals {
  # Same offset/octet scheme as deploy.tf's local.worker_macs, just producing
  # dotted IPs instead of MACs. Kept as a second computation (rather than
  # exported from deploy.tf) so this file reads standalone; the two must stay
  # in sync -- see the comment on local.worker_offsets in deploy.tf.
  worker_static_ips = [
    for oc in [for idx, w in local.rbe_workers : [floor((idx + 1) / 256), (idx + 1) % 256]] :
    "10.50.${oc[0]}.${oc[1]}"
  ]

  # Bumping any Buildbarn or monitoring image tag re-runs site.yml on its own,
  # without touching the earlier stages.
  bb_image_tags = join(",", [
    var.bb_storage_tag,
    var.bb_scheduler_tag,
    var.bb_browser_tag,
    var.bb_worker_tag,
    var.bb_runner_tag,
    var.bb_runner_base_image,
    var.prometheus_tag,
    var.grafana_tag,
    var.node_exporter_tag,
  ])
}

# ---------------------------------------------------------------------------
# Stage 0: let the qemu-guest-agent settle so the master's mgmt IP
# (ipv4_addresses[1][0] -- index 0 is loopback) is populated. Only the
# master is waited on here; every other worker is reached later purely by
# its Terraform-assigned static IP, once the master's DHCP server is live.
# ---------------------------------------------------------------------------
resource "time_sleep" "wait_for_master_agent" {
  create_duration = "30s"
  depends_on = [proxmox_virtual_environment_vm.rbe_worker]
}

# ---------------------------------------------------------------------------
# Single-host inventory for reaching the master via its mgmt IP, the same
# way source.tf reaches source_vm_id.
# ---------------------------------------------------------------------------
resource "local_file" "master_mgmt_inventory" {
  filename = "${path.module}/ansible/inventory/inventory_master.ini"

  content = templatefile("${path.module}/ansible/inventory/inventory_master.tpl", {
    master_name    = proxmox_virtual_environment_vm.rbe_worker[0].name
    master_mgmt_ip = proxmox_virtual_environment_vm.rbe_worker[0].ipv4_addresses[1][0]
    ssh_user       = var.vm_ssh_user
    ssh_password   = var.vm_ssh_password
  })

  depends_on = [time_sleep.wait_for_master_agent]
}

# ---------------------------------------------------------------------------
# Stage 1: pin the master's ens19 to 10.50.0.1 and turn on its DHCP server.
# This is the only host Terraform ever configures addressing on directly;
# every other worker gets its 10.50.x.x lease from this server, matched by
# the MAC deploy.tf already gave it.
# ---------------------------------------------------------------------------
resource "null_resource" "bootstrap_master" {
  triggers = {
    master    = proxmox_virtual_environment_vm.rbe_worker[0].id
    inventory = sha1(local_file.master_mgmt_inventory.content)
    # Re-run if the master's stable mgmt address changes, so ens18's secondary
    # static IP is re-applied.
    mgmt_ip   = var.master_mgmt_static_ip
    mgmt_mask = var.master_mgmt_netmask
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i ${path.module}/ansible/inventory/inventory_master.ini ${path.module}/ansible/bootstrap_master.yml \
        --extra-vars "master_mgmt_static_ip=${var.master_mgmt_static_ip}" \
        --extra-vars "master_mgmt_netmask=${var.master_mgmt_netmask}"
    EOT

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}

# ---------------------------------------------------------------------------
# Stage 2: poll every worker's static IP until it's reachable over SSH,
# rather than sleeping a fixed duration. Each worker now depends on the
# master's DHCP server (just started above) actually handing it a lease,
# which is more variable than the old "flip one interface" wait -- a fixed
# sleep would either be too short under load or wastefully long otherwise.
# ---------------------------------------------------------------------------
resource "time_sleep" "wait_for_workers" {
  create_duration = "15s"
  depends_on = [null_resource.bootstrap_master]

}

# ---------------------------------------------------------------------------
# Inventory for the actual Buildbarn deploy. Static IPs are computed
# directly from vm_id offset now -- no guest-agent lookup needed for
# workers at all, since the address was assigned by design (MAC + DHCP),
# not discovered after the fact.
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory/inventory.ini"

  content = templatefile("${path.module}/ansible/inventory/inventory.tpl", {
    workers = [
      for idx, vm in proxmox_virtual_environment_vm.rbe_worker : {
        name      = vm.name
        static_ip = local.worker_static_ips[idx]
      }
    ]
    ssh_user     = var.vm_ssh_user
    ssh_password = var.vm_ssh_password
  })
}

# ---------------------------------------------------------------------------
# Stage 3: deploy Buildbarn (firewall + storage/scheduler/browser on
# rbe_master, firewall + worker/runner on rbe_workers). The same tags that
# were pre-pulled onto the golden image are passed here, so every container
# starts from an image that is already cached locally.
# ---------------------------------------------------------------------------
resource "null_resource" "run_ansible_buildbarn" {
  triggers = {
    tags = local.bb_image_tags
    inventory = sha1(local_file.ansible_inventory.content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 15
      ansible-playbook -vvv -i ${path.module}/ansible/inventory/inventory.ini ${path.module}/ansible/site.yml \
        --forks 20 \
        --extra-vars "bb_storage_tag=${var.bb_storage_tag}" \
        --extra-vars "bb_scheduler_tag=${var.bb_scheduler_tag}" \
        --extra-vars "bb_browser_tag=${var.bb_browser_tag}" \
        --extra-vars "bb_worker_tag=${var.bb_worker_tag}" \
        --extra-vars "bb_runner_tag=${var.bb_runner_tag}" \
        --extra-vars "bb_runner_base_image=${var.bb_runner_base_image}" \
        --extra-vars "prometheus_tag=${var.prometheus_tag}" \
        --extra-vars "grafana_tag=${var.grafana_tag}" \
        --extra-vars "node_exporter_tag=${var.node_exporter_tag}"
    EOT

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }

  depends_on = [
    local_file.ansible_inventory,
    time_sleep.wait_for_workers
  ]
}

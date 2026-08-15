# Step 1: full clone of the source VM, converted straight to a template.
#
# The clone is taken only after null_resource.prewarm_source_images has
# finished pulling every Buildbarn image onto source_vm_id, so the template's
# disk already contains them. Nothing needs to boot or be provisioned here,
# which is why template = true is safe to set at creation time.
resource "proxmox_virtual_environment_vm" "template_source" {
  name      = var.template_name
  node_name = var.target_node
  vm_id     = var.template_vmid

  clone {
    vm_id = var.source_vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  # Convert this VM into a template once created
  template = true

  lifecycle {
    ignore_changes = [
      network_device,
      disk,
    ]
  }

  depends_on = [
    null_resource.prewarm_source_images,
    null_resource.install_dhcp_server,
  ]
}

locals {
  # One entry per VM, expanded from the per-node counts. Terraform walks maps
  # in lexicographic key order, so this runs local1's VMs, then local2's, and
  # so on.
  #
  # Position in this list is the only thing that determines a VM's VMID, and
  # therefore its static IP and MAC address (below). Node placement rides
  # along and feeds neither, which is what keeps the existing sequential
  # addressing scheme intact while the fleet spreads across nodes.
  rbe_workers = flatten([
    for node, worker_count in var.rbe_nodes : [
      for i in range(worker_count) : { node = node }
    ]
  ])

  # offset 1..N, one per worker, in the same order as local.rbe_workers.
  # rbe-worker-1 (offset 1) is always the master. This offset is the single
  # source of truth for both a worker's static cluster IP and its ens19 MAC
  # address, computed identically here (for the MAC, at creation time) and
  # in configure.tf (for the IP, at inventory-render time) -- so a lease
  # handed out by MAC always matches the address Ansible expects that host
  # to answer on.
  worker_offsets = [for idx, w in local.rbe_workers : idx + 1]

  # 10.50.<hi>.<lo>, scales past 254 hosts by carrying into the third octet.
  worker_octets = [for o in local.worker_offsets : [floor(o / 256), o % 256]]

  # Locally-administered, unicast prefix (02:...) + a recognizable ee:ee:ee
  # tag. Encodes each worker's offset directly into the last two octets, so
  # dhcp_reservations (below) can derive a deterministic 10.50.<hi>.<lo>
  # address per MAC with no runtime discovery involved.
  mgt_macs = [
    for oc in local.worker_octets :
    format("02:00:EE:EE:%02x:%02x", oc[0], oc[1])
  ]
  
  worker_macs = [
    for oc in local.worker_octets :
    format("02:EE:EE:EE:%02x:%02x", oc[0], oc[1])
  ]

  # Full reservation list, derived from the same MAC/offset data above --
  # this is the single source of truth dhcpd.conf gets templated from.
  # No arp-scan, no discovery: a MAC either has an entry here (and gets its
  # exact 10.50.<hi>.<lo> address) or it doesn't (and dhcpd never answers
  # it, since no pool/range is declared at all).
  dhcp_reservations = [
    for idx, mac in local.worker_macs : {
      name = "host-${local.worker_octets[idx][0]}-${local.worker_octets[idx][1]}"
      mac  = mac
      ip   = "10.50.${local.worker_octets[idx][0]}.${local.worker_octets[idx][1]}"
    }
  ]
}

resource "local_file" "dhcp_reservations" {
  filename = "${path.module}/ansible/dhcp_reservations.yml"
  content = yamlencode({
    dhcp_reservations = local.dhcp_reservations
  })
}

# Step 2: linked clones from the template, spread across the nodes named in
# rbe_nodes. The template stays put on var.target_node; because it lives on
# Ceph, any node can clone from it.
resource "proxmox_virtual_environment_vm" "rbe_worker" {
  count     = length(local.rbe_workers)
  node_name = local.rbe_workers[count.index].node
  vm_id     = var.clone_vmid_start + count.index
  name      = "rbe-worker-${count.index + 1}"
  stop_on_destroy = true
  #started   = count.index == 0 ? true : false


  clone {
    # Destination is node_name above; this is where the *source* template
    # lives. Omitting it defaults to the destination node, which is why this
    # only ever worked on a single node before.
    node_name = var.target_node
    vm_id     = proxmox_virtual_environment_vm.template_source.vm_id
    full      = false # linked clone
  }

  agent {
    enabled = true
  }

  # Two NICs, declared explicitly: net0 (mgmt) is plain DHCP as before; net1
  # (ens19, the cluster network) gets a MAC that encodes this worker's
  # offset, so the master's DHCP server can hand it its 10.50.x.x address
  # before Ansible ever needs to log in to assign one.
  network_device {
    bridge = var.mgmt_bridge
    model  = var.mgmt_network_model
    mac_address = local.mgt_macs[count.index]
    vlan_id = 0
  }

  network_device {
    bridge      = var.cluster_bridge
    model       = var.cluster_network_model
    mac_address = local.worker_macs[count.index]
    vlan_id     = var.cluster_vlan_id
  }

  depends_on = [proxmox_virtual_environment_vm.template_source]
}

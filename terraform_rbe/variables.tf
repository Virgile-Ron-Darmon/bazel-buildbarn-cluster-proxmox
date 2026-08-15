variable "target_node_url" {
  description = "Proxmox node name where VMs/template will live"
  type        = string
}

variable "target_node" {
  description = <<-EOT
    Proxmox node hosting source_vm_id and the template cloned from it. Worker
    placement is independent of this: with the template on Ceph, every node in
    rbe_nodes can linked-clone from it regardless of where it lives.
  EOT
  type        = string
}

variable "source_vm_id" {
  description = "VMID of the existing VM to clone as-is"
  type        = number
}

variable "template_name" {
  description = "Name to give the new template"
  type        = string
  default     = "rbe-worker-template"
}

variable "template_vmid" {
  description = "VMID to assign to the full clone that becomes the template"
  type        = number
}

variable "rbe_nodes" {
  description = <<-EOT
    Proxmox nodes to spread the cluster across, mapped to how many VMs each
    should host. Keys must be node names in the cluster.

    The template lives on target_node and every node listed here clones from
    it. That works because the backing storage is Ceph; on node-local storage
    a linked clone could not reference a template sitting on another node.

    Terraform iterates maps in lexicographic key order, so the fleet is laid
    out local1's VMs first, then local2's, and so on. VMIDs and static IPs
    are handed out sequentially in that order from clone_vmid_start, which
    makes the first VM of the first-sorting node rbe-worker-1, the one
    inventory.tpl promotes to cluster master. Renaming a node changes where
    it sorts and so reshuffles the fleet.

    A node may be set to 0 to drain it without removing the entry.
  EOT

  type = map(number)

  validation {
    # concat guards sum(), which rejects an empty list outright.
    condition     = sum(concat(values(var.rbe_nodes), [0])) >= 2
    error_message = "At least two VMs are required: rbe-worker-1 becomes the master (storage/scheduler/browser) and does not execute build actions itself."
  }

  validation {
    condition     = alltrue([for count in values(var.rbe_nodes) : count >= 0])
    error_message = "Worker counts cannot be negative."
  }
}

variable "clone_vmid_start" {
  description = "First VMID for linked clones; subsequent clones increment from here"
  type        = number
}

variable "mgmt_bridge" {
  type        = string
  description = "Proxmox bridge for net0 (mgmt interface, DHCP)"
}

variable "cluster_bridge" {
  type        = string
  description = "Proxmox bridge for net1 (ens19, the 10.50.x.x cluster network)"
}

variable "mgmt_network_model" {
  type        = string
  default     = "virtio"
  description = "NIC model for net0 (mgmt interface)"
}

variable "cluster_network_model" {
  type        = string
  default     = "e1000"
  description = "NIC model for net1 (ens19, the cluster network). Defaults to e1000 to match the source VM's existing driver."
}

variable "cluster_vlan_id" {
  type        = number
  default     = 50
  description = "VLAN tag for net1 (ens19, the cluster network)"
}

variable "pm_api_token_id" {
  type      = string
  sensitive = true
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

variable "vm_ssh_user" {
  type        = string
  description = "SSH user for connecting to the RBE worker VMs"
}

variable "vm_ssh_password" {
  type        = string
  description = "VM SSH passwprd"
}

variable "source_vm_ip" {
  type        = string
  description = "IP of source_vm_id, used to pre-warm the container images before cloning"
}

# Buildbarn does not publish a "latest" tag; every image is tagged with a
# timestamp + commit hash (e.g. "20260614T164626Z-1ae1eed"). These must be
# pinned explicitly and kept in sync with each other -- see the compatible
# tag sets in https://github.com/buildbarn/bb-deployments for known-good
# combinations. They're passed through to Ansible as --extra-vars by
# configure.tf, which is the only place they are defined at all.

variable "bb_storage_tag" {
  type        = string
  description = "Tag for ghcr.io/buildbarn/bb-storage (runs on rbe_master)"
}

variable "bb_scheduler_tag" {
  type        = string
  description = "Tag for ghcr.io/buildbarn/bb-scheduler (runs on rbe_master)"
}

variable "bb_browser_tag" {
  type        = string
  description = "Tag for ghcr.io/buildbarn/bb-browser (runs on rbe_master)"
}

variable "bb_worker_tag" {
  type        = string
  description = "Tag for ghcr.io/buildbarn/bb-worker (runs on rbe_workers)"
}

variable "bb_runner_tag" {
  type        = string
  description = "Tag for ghcr.io/buildbarn/bb-runner-installer (runs on rbe_workers)"
}

variable "bb_runner_base_image" {
  type        = string
  description = "Runner image name"
}
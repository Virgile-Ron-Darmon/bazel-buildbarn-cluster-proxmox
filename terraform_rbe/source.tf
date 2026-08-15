# Step 0: pre-warm the golden image.
#
# source_vm_id is a pre-existing VM that this Terraform does not manage; it is
# only ever read and cloned. Before deploy.tf full-clones it into the template,
# we pull every Buildbarn container image onto it, so the template and every
# linked clone downstream inherit a populated Docker image cache and never hit
# ghcr.io on first boot.
#
# Its IP is discovered the same way the workers' are: from the QEMU guest
# agent, second interface. Unlike the workers it gets no static 10.50.0.x
# address, since it is never a cluster member and only needs outbound access
# to the registry.

data "proxmox_vm" "source" {
  node_name = var.target_node
  id     = var.source_vm_id
}

resource "local_file" "source_inventory" {
  filename = "${path.module}/ansible/inventory/inventory_source.ini"

  content = templatefile("${path.module}/ansible/inventory/inventory_source.tpl", {
    source_name  = "rbe-source"
    source_ip    = var.source_vm_ip
    ssh_user     = var.vm_ssh_user
    ssh_password = var.vm_ssh_password
  })
}

resource "null_resource" "prewarm_source_images" {

  # Re-run whenever any tag changes, so the golden image can never carry a
  # stale image set relative to what the roles will later try to run.
  triggers = {
    source_vm_id         = var.source_vm_id
    bb_storage_tag       = var.bb_storage_tag
    bb_scheduler_tag     = var.bb_scheduler_tag
    bb_browser_tag       = var.bb_browser_tag
    bb_worker_tag        = var.bb_worker_tag
    bb_runner_tag        = var.bb_runner_tag
    bb_runner_base_image = var.bb_runner_base_image
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i ${path.module}/ansible/inventory/inventory_source.ini ${path.module}/ansible/prewarm_images.yml \
        --extra-vars "bb_storage_tag=${var.bb_storage_tag}" \
        --extra-vars "bb_scheduler_tag=${var.bb_scheduler_tag}" \
        --extra-vars "bb_browser_tag=${var.bb_browser_tag}" \
        --extra-vars "bb_worker_tag=${var.bb_worker_tag}" \
        --extra-vars "bb_runner_tag=${var.bb_runner_tag}" \
        --extra-vars "bb_runner_base_image=${var.bb_runner_base_image}"
    EOT
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }

  depends_on = [local_file.source_inventory]
}

resource "null_resource" "install_dhcp_server" {
  # No triggers tied to image tags: this only installs/configures packages
  # and templated config files on source_vm_id, it never starts the
  # service. Re-running install_dhcp.yml is idempotent, so this only really
  # needs to re-run if the source VM itself is replaced, or the fleet's
  # MAC/IP reservation list changes.
  triggers = {
    source_vm_id      = var.source_vm_id
    dhcp_reservations = jsonencode(local.dhcp_reservations)
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${path.module}/ansible/inventory/inventory_source.ini ${path.module}/ansible/install_dhcp.yml"

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }

  # Runs strictly after the image pull, not in parallel with it: both
  # provisioners hit source_vm_id over SSH, and running apt install
  # alongside several large `docker pull`s at once was enough to starve the
  # VM's CPU/IO and make sudo miss Ansible's become-prompt timeout (see
  # ansible.cfg for the timeout bump too, as a second line of defense).
  depends_on = [
    local_file.source_inventory,
    local_file.dhcp_reservations,
    null_resource.prewarm_source_images,
  ]
}

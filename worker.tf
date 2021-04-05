resource "hcloud_server" "worker" {
  name = "worker-${count.index}"
  image = "ubuntu-18.04"
  server_type = var.worker_server_type[count.index]
  location = "nbg1"
  ssh_keys = local.ssh_keys

  count = var.worker_cnt
}

resource "hcloud_server_network" "worker" {
  server_id = hcloud_server.worker[count.index].id
  network_id = hcloud_network.vb_cdap_k8s.id

  count = var.worker_cnt
}

locals {
  tmp_dir = "${path.root}/.terraform/tmp"
}

resource "null_resource" "tmp_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }
}

resource "null_resource" "worker_provisioners" {
  count = var.worker_cnt

  depends_on = [
    null_resource.master_provisioners,
    hcloud_floating_ip.vb_cdap_load_balancer,
    hcloud_server_network.worker,
    null_resource.tmp_dir,
  ]

  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.worker[count.index].ipv4_address
    agent = var.ssh_agent
    private_key = var.ssh_agent ? null : file(var.ssh_private_key_file)
  }

  # generate cluster join command
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_file} root@${hcloud_server.master.ipv4_address} kubeadm token create --print-join-command > ${local.tmp_dir}/cluster_join_worker-${count.index}"
  }

  provisioner "file" {
    source = "${path.module}/hack/setup-floating-ip.sh"
    destination = "/root/setup-floating-ip.sh"
  }

  provisioner "file" {
    source = "${path.module}/hack/bootstrap.sh"
    destination = "/root/bootstrap.sh"
  }

  provisioner "file" {
    source      = "${local.tmp_dir}/cluster_join_worker-${count.index}"
    destination = "/tmp/cluster_join"
  }

  provisioner "file" {
    source      = "${path.module}/hack/worker.sh"
    destination = "/root/worker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/hack/worker.sh"
    destination = "/root/worker.sh"
  }

  provisioner "file" {
    source      = var.worker_additional_setup_script == null ? "${path.module}/hack/dummy.sh" : var.worker_additional_setup_script
    destination = "/root/additional_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "/bin/bash /root/setup-floating-ip.sh ${hcloud_floating_ip.vb_cdap_load_balancer.ip_address}",
      "/bin/bash /root/bootstrap.sh",
      "/bin/bash /root/worker.sh",
      "/bin/bash /root/additional_setup.sh",
    ]
  }
}

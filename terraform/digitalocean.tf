resource "digitalocean_droplet" "web" {
  image      = var.do_image
  name       = var.do_name
  region     = var.do_region
  size       = var.do_size
  ssh_keys   = var.do_ssh_keys
  monitoring = var.do_monitoring
}

resource "time_sleep" "wait_for_droplet" {
  depends_on      = [digitalocean_droplet.web]
  create_duration = "30s"
}

resource "digitalocean_volume" "storage" {
  region                  = var.do_region
  name                    = var.do_name
  size                    = 40
  initial_filesystem_type = "ext4"
  description             = "backup storage"
}

resource "digitalocean_volume_attachment" "storage" {
  droplet_id = digitalocean_droplet.web.id
  volume_id  = digitalocean_volume.storage.id
}

resource "digitalocean_reserved_ip" "web" {
  depends_on = [time_sleep.wait_for_droplet]

  droplet_id = digitalocean_droplet.web.id
  region     = digitalocean_droplet.web.region
}

resource "digitalocean_firewall" "web" {
  name = var.do_firewall_name

  droplet_ids = [digitalocean_droplet.web.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.do_allow_ssh_only_from
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/host.yaml.tftpl", {
    reserved_ip          = digitalocean_reserved_ip.web.ip_address
    ssh_private_key_path = var.do_ssh_private_key_path
  })
  filename        = "${path.module}/../ansible/inventory/host.yaml"
  file_permission = "0644"
}

output "droplet_ip" {
  description = "Public ips of the droplets"
  value       = digitalocean_droplet.web.ipv4_address
}

output "ssh_command" {
  description = "SSH commands for all droplets"
  value       = "ssh -i ${var.do_ssh_private_key_path} root@${digitalocean_droplet.web.ipv4_address}"
}



resource "cloudflare_dns_record" "www" {
  for_each = toset(var.cf_record_name)

  depends_on = [digitalocean_reserved_ip.web]
  zone_id    = var.cf_zone_id
  name       = each.key
  ttl        = each.key == "vps" ? 300 : var.cf_ttl
  type       = var.cf_type
  comment    = "Managed by Terraform for ${each.key}"
  content    = digitalocean_reserved_ip.web.ip_address
  proxied    = each.key == "vps" ? false : var.cf_proxied
  settings = {
    ipv4_only = false
    ipv6_only = false
  }
}

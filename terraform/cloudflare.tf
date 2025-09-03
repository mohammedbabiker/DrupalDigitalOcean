resource "cloudflare_dns_record" "www" {
  for_each = toset(var.cf_record_name)

  depends_on = [digitalocean_droplet.web]
  zone_id    = var.cf_zone_id
  name       = each.key
  ttl        = var.cf_ttl
  type       = var.cf_type
  comment    = "Domain verification record"
  content    = digitalocean_droplet.web.ipv4_address
  proxied    = var.cf_proxied
  settings = {
    ipv4_only = false
    ipv6_only = false
  }
}
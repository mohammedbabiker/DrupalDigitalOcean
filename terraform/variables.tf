variable "do_token" {
  description = "The token for creater & destroy droplets"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.do_token) >= 40
    error_message = "Token should be at most 20 characters long"
  }
}

variable "do_image" {
  description = "Droplet OS image"
  type        = string
  validation {
    condition     = length(var.do_image) > 6
    error_message = "You have a typo in the image"
  }

}

variable "do_name" {
  description = "Base name for droplets"
  type        = string
  default     = "web"

}

variable "do_region" {
  description = "region for droplet"
  type        = string
  validation {
    condition     = length(var.do_region) == 4
    error_message = "You type a wrong region"
  }

}

variable "do_size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-512mb-10gb"

}

variable "do_ssh_keys" {
  description = "ssh keys listed"
  type        = list(string)
  sensitive   = true
}

variable "do_monitoring" {
  description = "Droplet monnitoring"
  type        = bool

}

variable "do_ssh_private_key_path" {
  description = "Path to your SSH private key"
  type        = string
  default     = "~/.ssh/ir_rsa"
}

variable "do_firewall_name" {
  description = "Droplet firewall for network acsess"
  type        = string
  default     = "only-22-and-443"

}

variable "do_allow_ssh_only_from" {
  description = "only allow ssh from this ip range"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]

}

variable "cf_zone_id" {
  description = "default zone id"
  type        = string
  sensitive   = true
}

variable "cf_record_name" {
  description = "record dns name"
  type        = list(string)

}

variable "cf_type" {
  description = "value of the private dns record type, only allowed options are 'A', 'AAAA', 'CNAME', 'MX', 'PTR', 'SRV', 'TXT'"
  type        = string
  default     = "A"

  validation {
    condition     = can(regex("^(A|AAAA|CNAME|MX|PTR|SRV|TXT)$", var.cf_type))
    error_message = "Invalid value for private dns record type, only allowed options are: 'A', 'AAAA', 'CNAME', 'MX', 'PTR', 'SRV', 'TXT'"
  }
}

variable "cf_ttl" {
  description = "Time To Live number"
  type        = number
  default     = 3600

}

variable "cf_proxied" {
  description = "proxied o' not"
  type        = bool

}

#!/usr/bin/env bash

set -x

certbot certonly \
  --agree-tos \
  --standalone \
  --rsa-key-size 2048 \
  --dns-digitalocean-propagation-seconds 30 \
  --dns-digitalocean-credentials /root/certbot/credentials.yaml \
  --no-eff-email -m you-emali@mail.com \
  -d your-domain.com

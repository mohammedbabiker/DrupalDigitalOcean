#!/usr/bin/env bash
set -euo pipefail

if nginx -t; then
  systemctl reload nginx
fi
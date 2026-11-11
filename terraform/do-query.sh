#!/usr/bin/env bash
set -eo pipefail

# 1. Verify DIGITALOCEAN_TOKEN is exported
if [ -z "$DIGITALOCEAN_TOKEN" ]; then
  echo "============================================================"
  echo "Error: DIGITALOCEAN_TOKEN environment variable is not set."
  echo "Please export your token before running this script:"
  echo ""
  echo "  export DIGITALOCEAN_TOKEN=\"your_do_personal_access_token\""
  echo "============================================================"
  exit 1
fi

# 2. Ensure required tools are installed
for cmd in curl jq column awk; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# Helper function to make GET requests and handle API errors
do_api_get() {
  local endpoint="$1"
  local response
  response=$(curl -s -X GET \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/${endpoint}")

  local api_error
  api_error=$(echo "$response" | jq -r '.message // empty')
  if [ -n "$api_error" ]; then
    echo "DigitalOcean API Error: $api_error" >&2
    exit 1
  fi
  echo "$response"
}

# Helper function for interactive field selection (used by Billing & Reserved IPs)
query_custom_field() {
  local endpoint="$1"
  local array_key="$2"
  local default_field="$3"
  local available_fields="$4"

  echo ""
  echo "Common fields for $array_key: $available_fields"
  read -rp "Enter the field to extract [default: $default_field, or type 'summary' for full table]: " FIELD
  FIELD="${FIELD:-$default_field}"

  echo ""
  echo "Fetching $array_key..."
  RESPONSE=$(do_api_get "$endpoint")

  echo ""
  echo "==================== Results ($array_key) ===================="
  if [ "$FIELD" == "summary" ]; then
    return 1 # Signal caller to render the summary table
  else
    echo "$RESPONSE" | jq -r --arg key "$array_key" --arg field "$FIELD" '
      .[$key][]? | .[$field] // empty
    ' | awk '{printf "%2d) %s\n", NR, $0}'
  fi
  echo "=============================================================="
  return 0
}

echo "--------------------------------------------------"
echo "DigitalOcean Resource & Billing CLI"
echo "--------------------------------------------------"
echo "Select a category:"
echo "  1) Sizes (Summary)"
echo "  2) Images (Summary)"
echo "  3) SSH Keys (Summary)"
echo "  4) Billing (Choose Option)"
echo "  5) Droplets (Summary)"
echo "  6) Firewalls (Summary)"
echo "  7) Reserved IPs (Choose Field / Summary)"
echo "--------------------------------------------------"

read -rp "Enter choice [1-7]: " main_choice

case "$main_choice" in
  1)
    echo ""
    echo "Fetching Sizes Summary..."
    RESPONSE=$(do_api_get "sizes?per_page=100")
    echo ""
    echo "==================== Sizes Summary ===================="
    echo "$RESPONSE" | jq -r '
      ["SLUG", "MEMORY(MB)", "VCPUS", "DISK(GB)", "PRICE/MO", "AVAILABLE"],
      (.sizes[] | [.slug, .memory, .vcpus, .disk, ("$" + (.price_monthly|tostring)), .available])
      | @tsv
    ' | column -t -s $'\t'
    echo "======================================================="
    ;;

  2)
    echo ""
    echo "Fetching Images Summary..."
    RESPONSE=$(do_api_get "images?per_page=100&type=distribution")
    echo ""
    echo "==================== Images Summary ===================="
    echo "$RESPONSE" | jq -r '
      ["ID", "DISTRIBUTION", "NAME", "SLUG"],
      (.images[] | [.id, .distribution, .name, (.slug // "N/A")])
      | @tsv
    ' | column -t -s $'\t'
    echo "========================================================"
    ;;

  3)
    echo ""
    echo "Fetching SSH Keys Summary..."
    RESPONSE=$(do_api_get "account/keys?per_page=100")
    echo ""
    echo "==================== SSH Keys Summary ===================="
    echo "$RESPONSE" | jq -r '
      ["ID", "NAME", "FINGERPRINT"],
      (.ssh_keys[] | [.id, .name, .fingerprint])
      | @tsv
    ' | column -t -s $'\t'
    echo "=========================================================="
    ;;

  4)
    echo ""
    echo "Select Billing Option:"
    echo "  1) Current Balance"
    echo "  2) List All Invoices"
    echo "  3) List All Billing History"
    read -rp "Enter choice [1-3]: " bill_choice

    case "$bill_choice" in
      1)
        echo ""
        echo "Fetching Customer Balance..."
        RESPONSE=$(do_api_get "customers/my/balance")
        echo ""
        echo "==================== Account Balance ===================="
        echo "$RESPONSE" | jq -r '
          "Month-to-Date Usage:   $" + .month_to_date_usage,
          "Account Balance:       $" + .account_balance,
          "Month-to-Date Balance: $" + .month_to_date_balance,
          "Generated At:          " + .generated_at
        '
        echo "========================================================="
        ;;
      2)
        if ! query_custom_field "customers/my/invoices?per_page=100" "invoices" "summary" "invoice_uuid, amount, invoice_period"; then
          echo "$RESPONSE" | jq -r '
            ["INVOICE_UUID", "PERIOD", "AMOUNT"],
            ((.invoices[]?, .invoice_preview?) | select(. != null) | [.invoice_uuid, .invoice_period, ("$" + .amount)])
            | @tsv
          ' | column -t -s $'\t'
          echo "=============================================================="
        fi
        ;;
      3)
        if ! query_custom_field "customers/my/billing_history?per_page=100" "billing_history" "summary" "description, amount, date, type, invoice_id"; then
          echo "$RESPONSE" | jq -r '
            ["DATE", "TYPE", "AMOUNT", "DESCRIPTION"],
            (.billing_history[] | [(.date | split("T")[0]), .type, ("$" + .amount), .description])
            | @tsv
          ' | column -t -s $'\t'
          echo "=============================================================="
        fi
        ;;
      *)
        echo "Invalid billing choice."
        exit 1
        ;;
    esac
    ;;

  5)
    echo ""
    echo "Fetching Droplets Summary..."
    RESPONSE=$(do_api_get "droplets?page=1&per_page=100")
    echo ""
    echo "==================== Droplets Summary ===================="
    echo "$RESPONSE" | jq -r '
      ["ID", "NAME", "STATUS", "IPV4", "REGION", "SIZE"],
      (.droplets[] | [
        .id,
        .name,
        .status,
        ([.networks.v4[]? | select(.type=="public") | .ip_address][0] // "N/A"),
        .region.slug,
        .size_slug
      ])
      | @tsv
    ' | column -t -s $'\t'
    echo "=========================================================="
    ;;

  6)
    echo ""
    echo "Fetching Firewalls Summary..."
    RESPONSE=$(do_api_get "firewalls?per_page=100")
    echo ""
    echo "==================== Firewalls Summary ===================="
    echo "$RESPONSE" | jq -r '
      ["ID", "NAME", "STATUS", "DROPLET_IDS", "INBOUND_RULES", "OUTBOUND_RULES"],
      (.firewalls[] | [
        .id,
        .name,
        .status,
        (.droplet_ids | map(tostring) | join(",") | if . == "" then "None" else . end),
        (.inbound_rules | length),
        (.outbound_rules | length)
      ])
      | @tsv
    ' | column -t -s $'\t'
    echo "==========================================================="
    ;;

  7)
    if ! query_custom_field "reserved_ips?page=1&per_page=20" "reserved_ips" "summary" "ip, droplet, region, locked"; then
      echo "$RESPONSE" | jq -r '
        ["IP_ADDRESS", "REGION", "ASSIGNED_DROPLET_ID", "DROPLET_NAME"],
        (.reserved_ips[] | [
          .ip,
          .region.slug,
          (.droplet.id // "Unassigned"),
          (.droplet.name // "N/A")
        ])
        | @tsv
      ' | column -t -s $'\t'
      echo "=============================================================="
    fi
    ;;

  *)
    echo "Invalid selection. Exiting."
    exit 1
    ;;
esac
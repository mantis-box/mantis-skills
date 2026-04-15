#!/usr/bin/env bash
# signal-matcher.sh — Hot path WSS → signal matching
# Reads WSS JSON events from stdin, matches against trading_rules.json thresholds
# Usage: cat <(ave-cloud-cli wss-repl) | signal-matcher.sh
# Or: signal-matcher.sh < /path/to/wss-events.jsonl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRADING_RULES_FILE="${TRADING_RULES_FILE:-${SCRIPT_DIR}/../trading_rules.json}"
GPIO_CONTROL="${SCRIPT_DIR}/gpio-control.sh"

# Load reflex rules from trading_rules.json
load_rules() {
  if [[ -f "$TRADING_RULES_FILE" ]]; then
    price_threshold=$(grep -o '"price_change_threshold_pct"[[:space:]]*:[[:space:]]*[0-9.]*' "$TRADING_RULES_FILE" | grep -o '[0-9.]*' | head -1 || echo "5.0")
    large_tx_threshold=$(grep -o '"large_tx_threshold_usd"[[:space:]]*:[[:space:]]*[0-9.]*' "$TRADING_RULES_FILE" | grep -o '[0-9.]*' | head -1 || echo "10000")
    whale_min_balance=$(grep -o '"whale_min_balance_usd"[[:space:]]*:[[:space:]]*[0-9.]*' "$TRADING_RULES_FILE" | grep -o '[0-9.]*' | head -1 || echo "50000")
  else
    price_threshold=5.0
    large_tx_threshold=10000
    whale_min_balance=50000
  fi
}

# Parse price update JSON and trigger LED if threshold crossed
handle_price_update() {
  local token price timestamp change_pct

  token=$(echo "$1" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  price=$(echo "$1" | grep -o '"price"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  timestamp=$(echo "$1" | grep -o '"timestamp"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1 || echo "0")

  # For price-based signals, we'd need previous price — simplified here
  # In production, maintain sliding window of prices
  if command -v bc &>/dev/null && [[ "$(echo "$price > 0" | bc 2>/dev/null)" == "1" ]]; then
    echo "[PRICE] token=$token price=$price ts=$timestamp"
  fi
}

# Parse tx update JSON and trigger LED for large txs
handle_tx_update() {
  local tx_hash timestamp side token_address amount_usd wallet amount_token

  tx_hash=$(echo "$1" | grep -o '"tx_hash"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  timestamp=$(echo "$1" | grep -o '"timestamp"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1 || echo "0")
  side=$(echo "$1" | grep -o '"side"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  token_address=$(echo "$1" | grep -o '"token_address"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  amount_token=$(echo "$1" | grep -o '"amount_token"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "0")
  amount_usd=$(echo "$1" | grep -o '"amount_usd"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  wallet=$(echo "$1" | grep -o '"wallet"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")

  echo "[TX] hash=$tx_hash side=$side token=$token_address amount_usd=$amount_usd wallet=${wallet:0:8}..."

  # Trigger LED for large transactions
  if command -v bc &>/dev/null; then
    is_large=$(echo "$amount_usd >= $large_tx_threshold" | bc 2>/dev/null || echo "0")
    if [[ "$is_large" == "1" ]]; then
      echo "[WHALE TX] Large transaction detected: \$$amount_usd USD"
      if [[ "$side" == "buy" ]]; then
        "$GPIO_CONTROL" green &
      else
        "$GPIO_CONTROL" red &
      fi
    fi
  fi
}

# Parse kline update
handle_kline_update() {
  local token chain open high low close volume
  token=$(echo "$1" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  chain=$(echo "$1" | grep -o '"chain"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
  open=$(echo "$1" | grep -o '"open"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  high=$(echo "$1" | grep -o '"high"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  low=$(echo "$1" | grep -o '"low"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  close=$(echo "$1" | grep -o '"close"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")
  volume=$(echo "$1" | grep -o '"volume"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*' | head -1 || echo "0")

  echo "[KLINE] token=$token chain=$chain O=$open H=$high L=$low C=$close V=$volume"

  # Calculate price change from open to close
  if command -v bc &>/dev/null && [[ "$(echo "$open > 0" | bc 2>/dev/null)" == "1" ]]; then
    change_pct=$(echo "scale=2; (($close - $open) / $open) * 100" | bc 2>/dev/null || echo "0")
    abs_change=$(echo "$change_pct" | tr -d '-' || echo "0")

    # Check if price change exceeds threshold
    exceeds=$(echo "$abs_change >= $price_threshold" | bc 2>/dev/null || echo "0")
    if [[ "$exceeds" == "1" ]]; then
      echo "[SIGNAL] Price change ${change_pct}% exceeds threshold ${price_threshold}%"
      if command -v bc &>/dev/null && [[ $(echo "$change_pct > 0" | bc 2>/dev/null || echo "0") == "1" ]]; then
        "$GPIO_CONTROL" green &
      else
        "$GPIO_CONTROL" red &
      fi
    fi
  fi
}

# Main: read lines from stdin and dispatch
main() {
  load_rules
  echo "[signal-matcher] Started with price_threshold=${price_threshold}% large_tx=\$${large_tx_threshold}"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Detect channel from JSON
    channel=$(echo "$line" | grep -o '"channel"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")

    case "$channel" in
      price)
        handle_price_update "$line"
        ;;
      tx)
        handle_tx_update "$line"
        ;;
      kline)
        handle_kline_update "$line"
        ;;
      *)
        # Try to extract any JSON for debugging
        if [[ "$line" =~ ^\{ ]]; then
          echo "[RAW] $line" >&2
        fi
        ;;
    esac
  done
}

main
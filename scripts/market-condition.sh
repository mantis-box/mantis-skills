#!/usr/bin/env bash
# market-condition.sh — Cold path alpha aggregation
# Usage: ./market-condition.sh [--update-rules]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRADING_RULES_FILE="${TRADING_RULES_FILE:-${SCRIPT_DIR}/../trading_rules.json}"
UPDATE_RULES=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-rules)
      UPDATE_RULES=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--update-rules]" >&2
      exit 1
      ;;
  esac
done

# Ensure ave-cloud-cli is available
if ! command -v ave-cloud-cli &>/dev/null; then
  echo "ERROR: ave-cloud-cli not found in PATH" >&2
  echo "Install: curl -fsSL https://raw.githubusercontent.com/owner/ave-cloud-cli/main/scripts/install.sh | sh" >&2
  exit 1
fi

# Ensure bc is available for math
if ! command -v bc &>/dev/null; then
  echo "ERROR: bc not found in PATH (required for calculations)" >&2
  exit 1
fi

echo "=== Mantis Alpha Hunter Report ==="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Market Mood Detection ---
echo "--- Market Mood ---"

# Aggregate sentiment from multiple sources
hot_tokens=$(ave-cloud-cli ranks --topic hot 2>/dev/null | head -20 || echo "")
gainer_count=$(ave-cloud-cli ranks --topic gainer 2>/dev/null | grep -c "price_change" || echo "0")
loser_count=$(ave-cloud-cli ranks --topic loser 2>/dev/null | grep -c "price_change" || echo "0")

# Determine mood based on gainer/loser ratio
if [[ "$gainer_count" -gt "$loser_count" ]]; then
  mood="bullish"
  mood_score=65
elif [[ "$loser_count" -gt "$gainer_count" ]]; then
  mood="bearish"
  mood_score=35
else
  mood="neutral"
  mood_score=50
fi

echo "Trend: $mood"
echo "Score: $mood_score/100"
echo ""

# --- Top Opportunities ---
echo "--- Top Opportunities ---"

echo "[HOT TOKENS]"
ave-cloud-cli ranks --topic hot 2>/dev/null | head -10 || echo "(unavailable)"
echo ""

echo "[TOP GAINERS]"
ave-cloud-cli ranks --topic gainer 2>/dev/null | head -10 || echo "(unavailable)"
echo ""

echo "[MEME TOKENS]"
ave-cloud-cli ranks --topic meme 2>/dev/null | head -10 || echo "(unavailable)"
echo ""

# --- Trending ---
echo "--- Trending ---"

echo "[BSC TRENDING]"
ave-cloud-cli trending --chain bsc 2>/dev/null | head -10 || echo "(unavailable)"
echo ""

echo "[SOLANA TRENDING]"
ave-cloud-cli trending --chain solana 2>/dev/null | head -10 || echo "(unavailable)"
echo ""

# --- Trading Signals ---
echo "--- Trading Signals ---"
ave-cloud-cli signals --chain solana 2>/dev/null | head -20 || echo "(unavailable)"
echo ""

# --- Whale Activity ---
echo "--- Whale Signals ---"
echo "[SMART WALLET ACTIVITY - BSC pump]"
ave-cloud-cli smart-wallets --chain bsc --keyword pump 2>/dev/null | head -20 || echo "(unavailable)"
echo ""

# --- Anomalies (placeholder for future) ---
echo "--- Anomalies ---"
echo "(anomaly detection requires additional data correlation — pending)"
echo ""

# --- Update trading_rules.json if requested ---
if [[ "$UPDATE_RULES" == "true" ]]; then
  echo "--- Updating trading_rules.json ---"

  # Build JSON output
  cat > "$TRADING_RULES_FILE" <<EOF
{
  "version": "1.0.0",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "market_mood": {
    "trend": "${mood}",
    "score": ${mood_score},
    "summary": "Alpha scan ${mood} — gainers: ${gainer_count}, losers: ${loser_count}"
  },
  "signals": {
    "buy": [],
    "sell": [],
    "hold": []
  },
  "top_opportunities": [],
  "anomalies": [],
  "whale_signals": [],
  "reflex_rules": {
    "price_change_threshold_pct": 5.0,
    "large_tx_threshold_usd": 10000,
    "whale_min_balance_usd": 50000,
    "momentum_lookback_blocks": 5,
    "refresh_interval_seconds": 60
  }
}
EOF

  echo "Updated: $TRADING_RULES_FILE"
fi

echo "=== End Report ==="

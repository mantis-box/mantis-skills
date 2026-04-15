# Trading Rules Schema

Schema reference for `trading_rules.json` — the shared contract between mantis-brain (cold path) and mantis-reflex (hot path).

## File Location

Default: `./trading_rules.json` (relative to script working directory)

Override: `TRADING_RULES_FILE=/path/to/rules.json`

## Schema

```json
{
  "version": "1.0.0",
  "generated_at": "2026-04-15T12:00:00Z",
  "market_mood": {
    "trend": "bullish",
    "score": 65,
    "summary": "Alpha scan bullish — gainers: 12, losers: 5"
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
```

## Field Descriptions

### Top-Level Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `version` | string | Yes | Schema version (currently `1.0.0`) |
| `generated_at` | string | Yes | ISO 8601 timestamp of generation |

### `market_mood`

| Field | Type | Description |
|---|---|---|
| `trend` | string | One of: `bullish`, `bearish`, `neutral` |
| `score` | int | Mood score 0-100 |
| `summary` | string | Human-readable summary |

### `signals`

| Field | Type | Description |
|---|---|---|
| `buy` | array | Buy signal tokens |
| `sell` | array | Sell signal tokens |
| `hold` | array | Hold signal tokens |

Each array entry is token-specific and extensible. Currently empty in cold path output.

### `top_opportunities`

Array of ranked token opportunities. Currently populated by cold path but schema is extensible.

### `anomalies`

Array of detected anomalies (rug pulls, unusual volume, etc.). Currently empty placeholder.

### `whale_signals`

Array of whale activity signals. Currently empty placeholder.

### `reflex_rules`

Hot path operational thresholds.

| Field | Type | Default | Description |
|---|---|---|---|
| `price_change_threshold_pct` | float | 5.0 | Price change % to trigger LED |
| `large_tx_threshold_usd` | float | 10000 | Minimum USD value for whale LED |
| `whale_min_balance_usd` | float | 50000 | Minimum wallet balance for whale flag |
| `momentum_lookback_blocks` | int | 5 | Blocks to look back for momentum |
| `refresh_interval_seconds` | int | 60 | How often reflex reloads rules |

## Example Full Document

```json
{
  "version": "1.0.0",
  "generated_at": "2026-04-15T12:00:00Z",
  "market_mood": {
    "trend": "bullish",
    "score": 72,
    "summary": "Alpha scan bullish — gainers: 15, losers: 6"
  },
  "signals": {
    "buy": ["0xtoken1", "0xtoken2"],
    "sell": [],
    "hold": ["0xtoken3"]
  },
  "top_opportunities": [
    {"token": "0xtoken1", "chain": "bsc", "rank": 1},
    {"token": "0xtoken2", "chain": "solana", "rank": 2}
  ],
  "anomalies": [],
  "whale_signals": [
    {"wallet": "0xwhale1", "chain": "bsc", "activity": "buy", "amount_usd": 75000}
  ],
  "reflex_rules": {
    "price_change_threshold_pct": 5.0,
    "large_tx_threshold_usd": 10000,
    "whale_min_balance_usd": 50000,
    "momentum_lookback_blocks": 5,
    "refresh_interval_seconds": 60
  }
}
```

## Gotchas

- **Write is atomic** — `market-condition.sh` writes via `cat > file <<EOF` which is atomic on POSIX filesystems
- **Read is NOT atomic** — `signal-matcher.sh` reads every 60s via `grep` on an open file descriptor; a partial write could produce garbled values
- **Reflex reads every 60 seconds** — changes to `reflex_rules` take up to 60s to take effect
- **Float parsing** — values like `5.0` are extracted via `grep -o '[0-9.]*'` which may capture more than intended in edge cases

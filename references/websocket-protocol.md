# WebSocket Protocol Reference

AVE Cloud WebSocket (WSS) event format for real-time mantis-reflex signal processing.

## Connection

```bash
ave-cloud-cli wss-repl
```

Requires `API_PLAN=pro`. The `free` and `normal` plans do not support WebSocket streams.

## Event Format

All WSS events are JSON objects on a single line:

```json
{"channel": "<channel_name>", ...}
```

## Channels

### `price` — Price Updates

```json
{
  "channel": "price",
  "token": "0x1234567890abcdef",
  "chain": "bsc",
  "price": 0.00234,
  "timestamp": 1713001234567
}
```

| Field | Type | Description |
|---|---|---|
| `channel` | string | Always `"price"` |
| `token` | string | Token contract address |
| `chain` | string | Chain identifier (`bsc`, `solana`) |
| `price` | float | Current price in USD |
| `timestamp` | int | Unix timestamp in milliseconds |

### `tx` — Transaction Updates

```json
{
  "channel": "tx",
  "tx_hash": "0xabcdef1234567890",
  "chain": "bsc",
  "side": "buy",
  "token_address": "0x1234567890abcdef",
  "amount_token": "1500.5",
  "amount_usd": 12500.00,
  "wallet": "0xabcdef1234567890abcdef1234567890",
  "timestamp": 1713001234567
}
```

| Field | Type | Description |
|---|---|---|
| `channel` | string | Always `"tx"` |
| `tx_hash` | string | Transaction hash |
| `chain` | string | Chain identifier |
| `side` | string | `"buy"` or `"sell"` |
| `token_address` | string | Token contract address |
| `amount_token` | string | Amount in token units |
| `amount_usd` | float | Amount in USD equivalent |
| `wallet` | string | Trader wallet address |
| `timestamp` | int | Unix timestamp in milliseconds |

### `kline` — OHLCV Candlestick Updates

```json
{
  "channel": "kline",
  "token": "0x1234567890abcdef",
  "chain": "bsc",
  "interval": "1m",
  "open": 0.00230,
  "high": 0.00245,
  "low": 0.00228,
  "close": 0.00234,
  "volume": 125000.5,
  "timestamp": 1713001234567
}
```

| Field | Type | Description |
|---|---|---|
| `channel` | string | Always `"kline"` |
| `token` | string | Token contract address |
| `chain` | string | Chain identifier |
| `interval` | string | Candle interval (`1m`, `5m`, `1h`) |
| `open` | float | Opening price |
| `high` | float | Highest price |
| `low` | float | Lowest price |
| `close` | float | Closing price |
| `volume` | float | Trading volume |
| `timestamp` | int | Unix timestamp in milliseconds |

## Example Event Stream

```
{"channel": "price", "token": "0x1234", "chain": "bsc", "price": 0.00234, "timestamp": 1713001234567}
{"channel": "tx", "tx_hash": "0xabcd", "chain": "bsc", "side": "buy", "token_address": "0x1234", "amount_token": "1500.5", "amount_usd": 12500.00, "wallet": "0xwalla", "timestamp": 1713001234568}
{"channel": "kline", "token": "0x1234", "chain": "bsc", "interval": "1m", "open": 0.00230, "high": 0.00245, "low": 0.00228, "close": 0.00234, "volume": 125000.5, "timestamp": 1713001234569}
```

## Signal Matching

The `signal-matcher.sh` script dispatches events by `channel`:

- `price` → logged for monitoring (requires sliding window for threshold detection)
- `tx` → if `amount_usd >= large_tx_threshold_usd` → trigger LED
- `kline` → calculate `(close - open) / open * 100`; if `|change_pct| >= price_change_threshold_pct` → trigger LED

## Gotchas

- **Channel detection relies on `"channel"\s*:\s*"<value>"` pattern** — if WSS payload format changes, signal matching breaks
- **Timestamps are in milliseconds** — divide by 1000 for Unix seconds
- **Amount fields are strings**, not floats — comparison requires type-aware parsing

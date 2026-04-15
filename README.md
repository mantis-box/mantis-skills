# Mantis Alpha Hunter Suite

Dual-path trading intelligence for SBC部署 — cold path (brain) for periodic analysis every 5 minutes, hot path (reflex) for real-time GPIO signals with sub-millisecond latency.

## Architecture

```
[COLD PATH]                      [HOT PATH]
   |                               |
   | market-condition.sh           |
   | (ave-cli ranks/trending/      |
   |  signals/smart-wallets)       |
   v                               |
[trading_rules.json] ──────────────>
   updated every 5 min             read every 60s
                                    |
                    mantis-daemon.sh
                    (ave-cli wss-repl)
                            |
                    signal-matcher.sh
                    (<1ms threshold check)
                            |
                    gpio-control.sh
                            |
                       [GPIO LEDs]
```

## Skills

| Skill | Purpose |
|---|---|
| `mantis-suite` | Router — routes to brain or reflex |
| `mantis-brain` | Cold path — market analysis + alpha aggregation (every 5 min) |
| `mantis-reflex` | Hot path — real-time WSS + GPIO LED control (sub-millisecond) |
| `mantis-telegram-ui` | ZeroClaw Telegram control plane — BotFather commands: status, startcron, stopcron, setrules |

## Quick Start

### Cold Path (Market Analysis)

```bash
# Full alpha report (triggered automatically every 5 min by ZeroClaw cron)
./scripts/market-condition.sh

# Update trading rules
./scripts/market-condition.sh --update-rules
```

### ZeroClaw Telegram Control Plane

BotFather commands via Telegram — human oversight of the trading system:

| Command | Description |
|---|---|
| `status` | Monitor cron, rules, and hardware state |
| `startcron` | Enable automatic 5-minute market tracking |
| `stopcron` | Suspend automatic updates (manual mode) |
| `setrules` | Override `trading_rules.json` manually |

### Hot Path (GPIO Daemon)

```bash
# Start daemon
./scripts/mantis-daemon.sh start

# Check status
./scripts/mantis-daemon.sh status

# Stop daemon
./scripts/mantis-daemon.sh stop

# Manual GPIO control
./scripts/gpio-control.sh green   # turn on green LED
./scripts/gpio-control.sh red     # turn on red LED
./scripts/gpio-control.sh yellow  # turn on yellow LED
./scripts/gpio-control.sh off     # turn off all LEDs
./scripts/gpio-control.sh status  # check LED states
```

## GPIO Pin Map

| LED Color | GPIO Pin | Signal |
|---|---|---|
| Red | 22 | danger / sell |
| Green | 27 | buy / go |
| Yellow | 17 | hold / caution |

## Environment Setup

```bash
export AVE_API_KEY="your_api_key_here"
export API_PLAN="pro"   # required for WSS hot path
```

## Systemd Service (Production)

```bash
# Install service
sudo cp mantis-reflexd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mantis-reflexd
sudo systemctl start mantis-reflexd

# Check status
sudo systemctl status mantis-reflexd
```

## Trading Rules Schema

`trading_rules.json` is the shared contract between brain and reflex:

```json
{
  "market_mood": { "trend": "bull|bear|neutral", "score": 0-100 },
  "signals": { "buy": [], "sell": [], "hold": [] },
  "top_opportunities": [],
  "anomalies": [],
  "whale_signals": [],
  "reflex_rules": {
    "price_change_threshold_pct": 5.0,
    "large_tx_threshold_usd": 10000,
    "whale_min_balance_usd": 50000
  }
}
```

See `trading_rules.json.example` for the full schema.

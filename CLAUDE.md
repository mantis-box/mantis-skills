# Mantis Alpha Hunter Suite — Claude Code Context

## Architecture Overview

Mantis is a dual-path trading intelligence system:

```
[COLD PATH - mantis-brain]          [HOT PATH - mantis-reflex]
         |                                    |
market-condition.sh                  mantis-daemon.sh
(ave-cli ranks/trending/             (ave-cli wss-repl)
 signals/smart-wallets)                      |
         |                                   signal-matcher.sh
         v                                          |
  trading_rules.json ──────────────────────────────▶
         |                                          |
         |                                   gpio-control.sh
         |                                          |
  Updated periodically                     [GPIO LEDs]
  (cron job)                               Red=22, Green=27, Yellow=17
```

## Cold Path (Brain)

- **Purpose**: Periodic market analysis — aggregates alpha signals into `trading_rules.json`
- **Entry**: `mantis-brain` skill → `market-condition` command
- **Script**: `scripts/market-condition.sh`
- **Commands called**:
  - `ave-cloud-cli ranks --topic hot`
  - `ave-cloud-cli ranks --topic gainer`
  - `ave-cloud-cli ranks --topic loser`
  - `ave-cloud-cli ranks --topic meme`
  - `ave-cloud-cli trending --chain bsc`
  - `ave-cloud-cli trending --chain solana`
  - `ave-cloud-cli signals --chain solana`
  - `ave-cloud-cli smart-wallets --chain bsc --keyword pump`

## Hot Path (Reflex)

- **Purpose**: Real-time WSS stream → signal matching → GPIO LED control (<1ms latency)
- **Entry**: `mantis-reflex` skill → `start-daemon` / `gpio-signal` commands
- **Daemon**: `scripts/mantis-daemon.sh` (PID: `/var/run/mantis-reflexd.pid`, log: `/var/log/mantis-reflexd.log`)
- **Signal matching**: `scripts/signal-matcher.sh` — reads WSS JSON, matches against `trading_rules.json` thresholds
- **GPIO control**: `scripts/gpio-control.sh` — controls LEDs on GPIO 22 (red), 27 (green), 17 (yellow)

## Shared State

`trading_rules.json` is the shared contract between brain and reflex:
- Brain writes it periodically (cold path)
- Reflex reads it every 60 seconds (hot path)
- Contains: market_mood, signals (buy/sell/hold), top_opportunities, anomalies, whale_signals, reflex_rules

## GPIO Pin Map

| LED Color | GPIO Pin | Signal |
|---|---|---|
| Red | 22 | danger / sell |
| Green | 27 | buy / go |
| Yellow | 17 | hold / caution |

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `AVE_API_KEY` | Yes | Ave Cloud API key |
| `API_PLAN` | Yes | `pro` required for WSS hot path |
| `TRADING_RULES_FILE` | No | Path to trading_rules.json (default: `./trading_rules.json`) |

## Skill Routing

| Skill | Directory | Purpose |
|---|---|---|
| `mantis-suite` | `skills/mantis-suite/` | Router — decides between brain/reflex |
| `mantis-brain` | `skills/mantis-brain/` | Cold path — market analysis |
| `mantis-reflex` | `skills/mantis-reflex/` | Hot path — real-time + GPIO |

## Dependencies

- `ave-cloud-cli` — must be built/installed
- Linux GPIO sysfs — kernel support + `gpio` group membership
- `bc` — math in market-condition.sh
- `systemd` — service management for daemon

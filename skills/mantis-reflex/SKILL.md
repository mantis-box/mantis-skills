---
name: mantis-reflex
version: 1.0.0
description: |
  Use this skill when the user wants to run the Mantis hot path: start daemon for real-time WSS
  signal stream, control GPIO LED indicators (red/green/yellow), or manually trigger LED signals.

  Also use for: stop daemon, check GPIO status, hot path vs cold path — reflex consumes
  trading_rules.json written by mantis-brain. Requires API_PLAN=pro.

license: MIT
metadata:
  openclaw:
    homepage: https://github.com/ave-air/mantis-skills
    emoji: "⚡"
    primaryEnv: AVE_API_KEY
    requires:
      env:
        - AVE_API_KEY
        - API_PLAN
      bins:
        - ave-cloud-cli
    allow_implicit_invocation: true

## Gotchas

- **Requires `API_PLAN=pro`** — WSS streams refuse `free`/`normal` plans; connections will silently fail
- **GPIO requires Linux with `gpio` group membership** — not available on macOS/Windows; `gpio-control.sh` silently succeeds if sysfs unavailable
- **Signal matcher uses `grep` for JSON parsing** — fragile if WSS payload format changes; channel detection relies on `"channel"\s*:\s*"<value>"` pattern
- **Daemon PID at `/var/run/mantis-reflexd.pid`** — if daemon crashes, PID file persists; clean up manually after crash
- **`trading_rules.json` must exist before daemon starts** — reflex reads thresholds at startup; if file missing, defaults are used (price_change_threshold_pct=5.0, large_tx_threshold_usd=10000)

---

# mantis-reflex

Hot path real-time signal processing. Monitors WSS stream, matches against `trading_rules.json`, and controls GPIO LEDs.

## Commands

### start-daemon

Starts the hot path daemon: pipes `ave-cloud-cli wss-repl` → `signal-matcher.sh` → `gpio-control.sh`.

```bash
./scripts/mantis-daemon.sh start
```

PID file: `/var/run/mantis-reflexd.pid`
Log file: `/var/log/mantis-reflexd.log`

### stop-daemon

Stops the hot path daemon.

```bash
./scripts/mantis-daemon.sh stop
```

### gpio-status

Check current LED states.

```bash
./scripts/gpio-control.sh status
```

### gpio-signal

Manually trigger an LED.

```bash
./scripts/gpio-control.sh red     # danger/sell
./scripts/gpio-control.sh green   # buy/go
./scripts/gpio-control.sh yellow  # hold/caution
./scripts/gpio-control.sh off     # turn off all
```

## GPIO Pin Map

| LED Color | GPIO Pin | Signal |
|---|---|---|
| Red | 22 | danger / sell |
| Green | 27 | buy / go |
| Yellow | 17 | hold / caution |

## Signal Matching Rules

The signal matcher reads WSS JSON events from stdin and matches against `trading_rules.json`:

- **Price change > reflex_rules.price_change_threshold_pct** → green (buy) or red (sell)
- **Large tx (>$10k USD)** from whales → triggers LED
- **Whale wallet activity** on tracked tokens → signals

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `AVE_API_KEY` | (required) | Ave Cloud API key |
| `API_PLAN` | `pro` | Must be `pro` for WSS |
| `TRADING_RULES_FILE` | `./trading_rules.json` | Path to trading rules |
| `MANTIS_LOG` | `/var/log/mantis-reflexd.log` | Daemon log path |
| `MANTIS_PID` | `/var/run/mantis-reflexd.pid` | Daemon PID path |

## Workflow Example

```bash
# Start the hot path daemon
./scripts/mantis-daemon.sh start

# Check daemon status
./scripts/mantis-daemon.sh status

# View logs
tail -f /var/log/mantis-reflexd.log

# Manually trigger green LED (buy signal)
./scripts/gpio-control.sh green

# Stop the daemon
./scripts/mantis-daemon.sh stop
```

## Systemd Service (Production)

```bash
sudo systemctl start mantis-reflexd
sudo systemctl stop mantis-reflexd
sudo systemctl status mantis-reflexd
```

## Reference

- [mantis-brain](../mantis-brain/SKILL.md) — cold path that writes trading_rules.json
- [signal-matcher.sh](scripts/signal-matcher.sh) — WSS event matching logic
- [gpio-control.sh](scripts/gpio-control.sh) — GPIO LED controller
- [websocket-protocol.md](../references/websocket-protocol.md) — WSS event format
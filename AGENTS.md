# Mantis Skills — Agent Decision Table

Quick routing reference for Claude Code agents working with the Mantis suite.

## Decision Matrix

| User Request | Route To | Command |
|---|---|---|
| "alpha report", "market condition", "update rules" | `mantis-brain` | `market-condition` |
| "whale activity", "smart wallets", "top tokens" | `mantis-brain` | `market-condition` |
| "start daemon", "watch signals", "live stream" | `mantis-reflex` | `start-daemon` |
| "GPIO LED", "turn on green", "LED status" | `mantis-reflex` | `gpio-signal` / `gpio-status` |
| "stop daemon" | `mantis-reflex` | `stop-daemon` |
| "what's trending", "hot tokens", "gainers/losers" | `mantis-brain` | `market-condition` |
| "real-time price", "WSS stream" | `mantis-reflex` | `start-daemon` |

## Cold Path (mantis-brain)

**Use when**: User wants alpha aggregation, market mood analysis, periodic updates to `trading_rules.json`

**Commands**:
- `market-condition` → full alpha report + optionally writes `trading_rules.json`
- `update-rules` → reads market-condition output, writes `trading_rules.json`

**典型场景**:
- "give me the alpha"
- "update the trading rules"
- "scan for whale activity"
- "what tokens are hot"

## Hot Path (mantis-reflex)

**Use when**: User wants real-time GPIO control, WSS monitoring daemon, LED signal feedback

**Commands**:
- `start-daemon` → starts WSS → signal-matcher → GPIO pipeline
- `stop-daemon` → stops the daemon
- `gpio-status` → check current LED states
- `gpio-signal <color>` → manually trigger LED (red/green/yellow/off)

**典型场景**:
- "start the signal daemon"
- "turn on the green LED"
- "watch for buy signals"
- "check GPIO status"

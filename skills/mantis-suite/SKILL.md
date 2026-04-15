---
name: mantis-suite
version: 1.0.0
description: |
  Use this skill when the user wants to run the Mantis Alpha Hunter system — either cold path market
  analysis (alpha hunter, market mood, whale signals, GPIO LED indicators) or hot path real-time
  signal processing (WSS stream, start daemon, GPIO control, LED signals).

  Routes to mantis-brain for: alpha report, market condition, trading rules update, top opportunities,
  whale activity, hot tokens, trending tokens.

  Routes to mantis-reflex for: start daemon, watch signals, GPIO LED control, real-time stream,
  hot path vs cold path selection.

license: MIT
metadata:
  openclaw:
    homepage: https://github.com/ave-air/mantis-skills
    emoji: "🦗"
    primaryEnv: AVE_API_KEY
    requires:
      env:
        - AVE_API_KEY
        - API_PLAN
      bins:
        - ave-cloud-cli
    allow_implicit_invocation: true

# mantis-suite

Router skill for the Mantis Alpha Hunter suite. Splits into cold path (brain) and hot path (reflex).

## Route Selection

| User intent | Use |
|---|---|
| Market analysis, alpha report, update trading rules | `mantis-brain` |
| Real-time WSS monitoring, GPIO LED control, daemon start/stop | `mantis-reflex` |

## Decision Matrix

| User says | Use | Ask first |
|---|---|---|
| "alpha report", "market condition", "update rules" | `mantis-brain` | — |
| "start daemon", "watch signals", "GPIO", "LED" | `mantis-reflex` | — |
| "what's hot", "top tokens", "whale activity" | `mantis-brain` | chain if ambiguous |
| "live price", "stream tx", "real-time" | `mantis-reflex` | — |

## Gotchas

- **Run `mantis-brain` first if both needed** — brain populates `trading_rules.json` which reflex reads; reflex daemon will not function correctly without it
- **Reflex daemon will not start if `trading_rules.json` doesn't exist** — run `market-condition.sh --update-rules` via mantis-brain before starting daemon
- **"alpha report" routes to brain, "start daemon" routes to reflex** — ensure user intent is clear before routing

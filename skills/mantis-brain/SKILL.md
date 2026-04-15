---
name: mantis-brain
version: 1.0.0
description: |
  Use this skill when the user wants to run the Mantis cold path: generate an alpha hunter report
  showing market mood, top opportunities, whale signals, and trading anomalies from AVE Cloud API.

  Also use for: update trading_rules.json with current market data, periodic market scan via cron,
  cold path vs hot path — brain writes rules that reflex reads.

license: MIT
metadata:
  openclaw:
    homepage: https://github.com/ave-air/mantis-skills
    emoji: "🧠"
    primaryEnv: AVE_API_KEY
    requires:
      env:
        - AVE_API_KEY
        - API_PLAN
      bins:
        - ave-cloud-cli
    allow_implicit_invocation: true

# mantis-brain

Cold path market analysis skill. Aggregates alpha signals from AVE Cloud API into `trading_rules.json`.

## Commands

### market-condition

Aggregates alpha signals by calling in sequence:
- `ave-cloud-cli ranks --topic hot` — Hot tokens
- `ave-cloud-cli ranks --topic gainer` — Top gainers
- `ave-cloud-cli ranks --topic loser` — Top losers
- `ave-cloud-cli ranks --topic meme` — Meme tokens
- `ave-cloud-cli trending --chain bsc` — BSC trending
- `ave-cloud-cli trending --chain solana` — Solana trending
- `ave-cloud-cli signals --chain solana` — Trading signals
- `ave-cloud-cli smart-wallets --chain bsc --keyword pump` — Whale activity

Outputs alpha hunter report with market mood, top opportunities, anomalies, whale signals.

With `--update-rules` flag: generates `trading_rules.json` with buy/sell signals, thresholds, and reflex_rules.

```bash
# Alpha report only
./scripts/market-condition.sh

# Alpha report + update trading_rules.json
./scripts/market-condition.sh --update-rules

# Custom output path
TRADING_RULES_FILE=/path/to/rules.json ./scripts/market-condition.sh --update-rules
```

### update-rules

Writes `trading_rules.json` from current market analysis. Called automatically by `market-condition --update-rules` or run standalone:

```bash
./scripts/market-condition.sh --update-rules
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `AVE_API_KEY` | (required) | Ave Cloud API key |
| `API_PLAN` | `free` | API plan (free/normal/pro) |
| `TRADING_RULES_FILE` | `./trading_rules.json` | Output path for trading rules |

## Gotchas

- **`API_PLAN=free` throttles to 1 req/min** — use `API_PLAN=normal` or `pro` for production scans
- **`trading_rules.json` write is atomic but read is not** — reflex reads every 60s via `grep`; a partial write during read could produce garbled threshold values
- **`market-condition.sh` requires `bc` for math** — Raspbian minimal may not have it installed; install with `sudo apt install bc`
- **`--update-rules` overwrites existing rules** — any manual edits to `trading_rules.json` are lost on next run

## Output Format

Alpha report sections:
1. **Market Mood** — bull/bear/neutral with score (0-100)
2. **Top Opportunities** — ranked tokens with metrics
3. **Anomalies** — unusual volume, rug pulls, suspicious activity
4. **Whale Signals** — smart wallet activity, large transactions
5. **Trading Signals** — buy/sell/hold recommendations

## Workflow Example

```bash
# Run alpha scan
./scripts/market-condition.sh

# Update trading rules for hot path to consume
./scripts/market-condition.sh --update-rules
```

## Reference

- [mantis-reflex](../mantis-reflex/SKILL.md) — hot path that consumes trading_rules.json
- [trading_rules.json.example](../../trading_rules.json.example) — schema reference

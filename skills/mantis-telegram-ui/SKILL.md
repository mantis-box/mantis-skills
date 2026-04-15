---
name: mantis-telegram-ui
version: 1.0.0
description: |
  Use this skill when the user initiates a Telegram BotFather slash command (like /status, /startcron, /stopcron, or /setrules)
  or wants to manage the mantis background cron and override trading rules via chat.
license: MIT
metadata:
  openclaw:
    emoji: "📱"
    requires:
      bins:
        - zeroclaw
        - ave-cloud-cli
---

# Mantis Telegram UI & Control

You are operating an interactive UI over Telegram for the Mantis trading suite. The user has set up slash commands via BotFather to control the cron and override trading rules. 

When the user triggers one of the configured slash commands, follow the explicit instructions below. **Never output raw JSON or command-line logs back to the user.** Always format the data as clean, readable Telegram messages (with emojis).

## `/status`
Monitors the current system state, including cron, active rules, and hardware.
1. Check the background cron: `zeroclaw cron list` (Look for the market-condition job).
2. Read the current trading rules: read the contents of `$TRADING_RULES_FILE` (or `/opt/mantis/trading_rules.json` if the env var isn't set).
3. Check hardware: execution `/opt/mantis/scripts/gpio-control.sh status`.
4. Combine this information into a succinct dashboard response:
   - **Cron Status:** (Running / Stopped)
   - **Market Mood:** (From trading rules)
   - **Active Hot Path Signal:** Buy/Sell/Hold
   - **Hardware Status:** LEDs states

## `/startcron`
Resumes the automatic 5-minute cold path scans.
1. Add the cron job strictly using this command format, adhering to ZeroClaw best practices by invoking the appropriate skill intent rather than raw shell paths:
   ```bash
   zeroclaw cron add "*/5 * * * *" --prompt "Run the mantis-brain skill to generate an alpha report and update trading rules"
   ```
2. Respond: 🟢 `Automatic market tracking enabled. Rules will update every 5 minutes.`

## `/stopcron`
Halts the automatic updates so the user can manually drive trading decisions.
1. Find the cron job: `zeroclaw cron list`
2. Remove the relevant cron job by finding its ID and executing `zeroclaw cron remove <id>`
3. Respond: 🛑 `Automatic scanning halted. You are in manual mode.`

## `/setrules`
Allows the user to manually override the active trading rules.
1. The user might type `/setrules Buy PEPE threshold 0.5` or similar. 
2. Before updating the file, check if the cron is currently running (`zeroclaw cron list`). If it is, explicitly remove it (to prevent the cron from instantly overwriting the user's manual rules) and inform the user.
3. Use the `file_io` tool or `echo` via the `shell` tool to overwrite the `$TRADING_RULES_FILE` (or `/opt/mantis/trading_rules.json`) with a valid JSON representation mapping their requests into the Mantis shared state schema.
4. Respond: 🛠️ `Trading rules strictly overridden for hot path consumption.`

## Notes
- Expect the user to send commands like `/startcron` directly in chat. Treat this as an explicit imperative.
- If `$TRADING_RULES_FILE` is not set, default to `/opt/mantis/trading_rules.json`.
- Keep responses short. Mobile telegram clients have small screens.

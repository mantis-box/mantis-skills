# Daemon Fail-Safe Reference

Fail-safe behavior when the mantis-reflex daemon crashes, plus log rotation, PID cleanup, and restart logic.

## PID File

- **Path:** `/var/run/mantis-reflexd.pid`
- **Contains:** PID of the running daemon process

## Fail-Safe Behavior

### On Unexpected Exit (Crash)

1. **PID file persists** — if daemon crashes, PID file is not cleaned up
2. **On restart**, `mantis-daemon.sh start` detects stale PID via `kill -0` check
3. **Stale PID cleanup** — if process no longer exists, PID file is overwritten

### On Clean Stop

1. LEDs are turned off via `gpio-control.sh off`
2. Process receives SIGTERM (or SIGKILL after 5s timeout)
3. PID file is removed

## Log Rotation

- **Path:** `/var/log/mantis-reflexd.log`
- **No automatic rotation** — implement logrotate manually:

```bash
# /etc/logrotate.d/mantis-reflex
/var/log/mantis-reflexd.log {
    daily
    rotate 7
    compress
    delaycompress
    postrotate
        # Optional: signal daemon to reopen log file
        kill -USR1 $(cat /var/run/mantis-reflexd.pid) 2>/dev/null || true
    endscript
}
```

## Manual Recovery After Crash

If daemon crashed and PID file was left behind:

```bash
# Check if process actually running
cat /var/run/mantis-reflexd.pid
kill -0 $(cat /var/run/mantis-reflexd.pid) 2>/dev/null && echo "running" || echo "stale"

# Clean up stale PID
rm -f /var/run/mantis-reflexd.pid

# Restart daemon
./scripts/mantis-daemon.sh start
```

## Restart Logic

```bash
./scripts/mantis-daemon.sh restart
```

The restart sequence:
1. Stop (SIGTERM, 5s timeout, SIGKILL if needed)
2. Remove PID file
3. Sleep 1 second
4. Start fresh

## Health Check

```bash
./scripts/mantis-daemon.sh status
```

Shows:
- Running status with PID
- Last 10 lines of log

## Known Failure Modes

| Failure | Cause | Recovery |
|---|---|---|
| `wss-repl` fails | Invalid API key, network issue | Check `AVE_API_KEY`, network connectivity |
| `signal-matcher` silent | `trading_rules.json` missing | Run `mantis-brain` first to create rules |
| GPIO error | No `gpio` group, no sysfs | See `gpio-pinmap.md` troubleshooting |
| Daemon appears running but no logs | Log file permissions | `sudo chmod 666 /var/log/mantis-reflexd.log` |

## Startup Sequence

```
mantis-daemon.sh start
  └─ check_env()
      └─ verify AVE_API_KEY set
  └─ mkdir -p for log directory
  └─ chmod +x for signal-matcher.sh, gpio-control.sh
  └─ nohup ave-cloud-cli wss-repl 2>/dev/null |
  │     signal-matcher.sh > log 2>&1 &
  └─ write PID to /var/run/mantis-reflexd.pid
  └─ sleep 1
  └─ is_running() check
```

## Shutdown Sequence

```
mantis-daemon.sh stop
  └─ is_running() check
  └─ gpio-control.sh off (turn off LEDs)
  └─ kill $PID (SIGTERM)
  └─ wait up to 10 iterations × 0.5s = 5s for graceful exit
  └─ kill -9 $PID if still alive
  └─ rm -f /var/run/mantis-reflexd.pid
```

# Daemon Deployment Checklist

Use this checklist when deploying the mantis-reflex daemon to production.

## Prerequisites

- [ ] `API_PLAN=pro` set (WSS requires pro — free/normal plans will fail silently)
- [ ] `AVE_API_KEY` set and valid
- [ ] `ave-cloud-cli` installed and in PATH
- [ ] `trading_rules.json` exists (run `mantis-brain --update-rules` first)
- [ ] `bc` installed (required for threshold calculations)

## Linux Setup

- [ ] User is member of `gpio` group: `groups $USER`
- [ ] If not: `sudo usermod -aG gpio $USER` then re-login
- [ ] `/var/run/` is writable (for PID file) OR set `MANTIS_PID=$HOME/.mantis-reflexd.pid`
- [ ] `/var/log/` is writable (for log file) OR set `MANTIS_LOG=$HOME/.mantis-reflexd.log`

## First Start

- [ ] Run: `AVE_API_KEY=xxx API_PLAN=pro ./scripts/mantis-daemon.sh start`
- [ ] Check: `./scripts/mantis-daemon.sh status`
- [ ] Verify: LEDs flash on startup
- [ ] Check: `tail /var/log/mantis-reflexd.log` shows WSS connection

## Daemon Management

```bash
# Start
./scripts/mantis-daemon.sh start

# Check status
./scripts/mantis-daemon.sh status

# View logs
tail -f /var/log/mantis-reflexd.log

# Stop
./scripts/mantis-daemon.sh stop
```

## Troubleshooting

| Issue | Check |
|---|---|
| "AVE_API_KEY not set" | Export AVE_API_KEY before starting |
| "WSS may not work" warning | Ensure `API_PLAN=pro` |
| Daemon starts but no LED activity | Verify `trading_rules.json` exists |
| Permission denied on GPIO | Add user to `gpio` group |
| Log shows connection refused | Check network, API key validity |

## Systemd Service (Production)

```bash
# Copy service file
sudo cp mantis-reflexd.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable mantis-reflexd

# Start now
sudo systemctl start mantis-reflexd
```

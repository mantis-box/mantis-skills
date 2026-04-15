# GPIO Pin Map Reference

GPIO setup, sysfs paths, permissions, and troubleshooting for Mantis LED control.

## Pin Map

| LED Color | GPIO Pin | Signal | Sysfs Path |
|---|---|---|---|
| Red | 22 | danger / sell | `/sys/class/gpio/gpio22` |
| Green | 27 | buy / go | `/sys/class/gpio/gpio27` |
| Yellow | 17 | hold / caution | `/sys/class/gpio/gpio17` |

## Sysfs Interface

Linux GPIO character device interface via `/sys/class/gpio/`:

```bash
# Export pin
echo 22 > /sys/class/gpio/export

# Set direction
echo out > /sys/class/gpio/gpio22/direction

# Write value
echo 1 > /sys/class/gpio/gpio22/value

# Unexport
echo 22 > /sys/class/gpio/unexport
```

## Requirements

1. **Linux kernel** with GPIO sysfs support (standard on Raspbian)
2. **gpio group membership** — user must be in the `gpio` group:
   ```bash
   sudo usermod -aG gpio $USER
   ```
3. **No root required** — sysfs GPIO does not need root if group membership is set

## Permissions

GPIO sysfs is group-writable for `gpio` group. Verify:

```bash
ls -la /sys/class/gpio/
# gpiochip0 should show group gpio with write permission
```

If permission denied:
- Check `gpio` group: `groups $USER`
- Re-login or use `newgrp gpio` after adding
- On some systems, need to add udev rule in `/etc/udev/rules.d/`:

```bash
# /etc/udev/rules.d/99-gpio.rules
SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
SUBSYSTEM=="gpiochip*", GROUP="gpio", MODE="0660"
```

## Troubleshooting

### LED Not Lighting

1. **Check sysfs availability:**
   ```bash
   ls /sys/class/gpio/
   ```
   If directory missing, kernel may not have CONFIG_GPIO_SYSFS=y

2. **Check pin export:**
   ```bash
   cat /sys/class/gpio/gpio22/value
   ```
   If ENOENT, pin not exported yet — `gpio-control.sh` auto-exports on first use

3. **Check actual pin state:**
   ```bash
   cat /sys/class/gpio/gpio22/direction  # should be "out"
   cat /sys/class/gpio/gpio22/value     # should be "1" when on
   ```

### "Permission Denied" on Export

User not in `gpio` group or sysfs mounted read-only. Try:

```bash
# Check group
groups

# Check sysfs mount
mount | grep gpio
# Should show rw if writable

# Manual export test
echo 22 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio22/direction
echo 1 > /sys/class/gpio/gpio22/value
```

### LED Always Off After Reboot

GPIO pins reset to default state on reboot. The daemon should call `gpio-control.sh off` on startup to ensure known state. If not, manually reset:

```bash
./scripts/gpio-control.sh off
```

### LED Stays On / Wrong Color

1. Check for multiple processes writing to same pin
2. Restart daemon: `./scripts/mantis-daemon.sh restart`
3. Manually toggle: `./scripts/gpio-control.sh red && ./scripts/gpio-control.sh off`

## cross-platform Note

GPIO sysfs is **Linux-only**. The hot path (mantis-reflex) will not function on macOS or Windows. The `gpio-control.sh` script silently succeeds if sysfs is unavailable (all operations use `|| true` guards).

## LED Behavior Summary

| Command | Red (22) | Green (27) | Yellow (17) |
|---|---|---|---|
| `gpio-control.sh red` | ON | OFF | OFF |
| `gpio-control.sh green` | OFF | ON | OFF |
| `gpio-control.sh yellow` | OFF | OFF | ON |
| `gpio-control.sh off` | OFF | OFF | OFF |
| `gpio-control.sh status` | read | read | read |

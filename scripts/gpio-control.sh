#!/usr/bin/env bash
# gpio-control.sh — GPIO LED controller for Mantis hot path
# Controls LEDs on GPIO 22 (red), 27 (green), 17 (yellow)
# Usage: gpio-control.sh {red|green|yellow|off|status}

set -euo pipefail

# GPIO pin definitions
GPIO_RED=22
GPIO_GREEN=27
GPIO_YELLOW=17

# sysfs path
SYSFS_GPIO="/sys/class/gpio"

# Color to pin mapping
declare -A PIN_MAP=(
  [red]=$GPIO_RED
  [green]=$GPIO_GREEN
  [yellow]=$GPIO_YELLOW
)

# Export GPIO pin if not already exported
ensure_export() {
  local pin=$1
  local pin_path="$SYSFS_GPIO/gpio${pin}"
  if [[ ! -d "$pin_path" ]]; then
    echo "$pin" > "$SYSFS_GPIO/export" 2>/dev/null || true
    sleep 0.1
  fi
}

# Set pin direction to output
ensure_direction() {
  local pin=$1
  local pin_path="$SYSFS_GPIO/gpio${pin}/direction"
  if [[ -f "$pin_path" ]]; then
    echo "out" > "$pin_path" 2>/dev/null || true
  fi
}

# Write pin value
write_pin() {
  local pin=$1
  local value=$2
  local pin_path="$SYSFS_GPIO/gpio${pin}/value"
  if [[ -f "$pin_path" ]]; then
    echo "$value" > "$pin_path" 2>/dev/null || true
  fi
}

# Turn off all LEDs
all_off() {
  for color in red green yellow; do
    local pin=${PIN_MAP[$color]}
    ensure_export "$pin"
    ensure_direction "$pin"
    write_pin "$pin" 0
  done
}

# Turn on specific LED
led_on() {
  local color=$1
  local pin=${PIN_MAP[$color]:-}
  if [[ -z "$pin" ]]; then
    echo "Unknown color: $color" >&2
    echo "Usage: $0 {red|green|yellow|off|status}" >&2
    exit 1
  fi

  all_off
  ensure_export "$pin"
  ensure_direction "$pin"
  write_pin "$pin" 1
  echo "LED $color (GPIO $pin) ON"
}

# Get LED status
led_status() {
  echo "GPIO LED Status:"
  echo "----------------"
  for color in red green yellow; do
    local pin=${PIN_MAP[$color]}
    ensure_export "$pin" 2>/dev/null || true
    local pin_path="$SYSFS_GPIO/gpio${pin}/value"
    if [[ -f "$pin_path" ]]; then
      local state
      state=$(cat "$pin_path" 2>/dev/null || echo "0")
      if [[ "$state" == "1" ]]; then
        echo "  GPIO $pin ($color): ON"
      else
        echo "  GPIO $pin ($color): OFF"
      fi
    else
      echo "  GPIO $pin ($color): NOT EXPORTED"
    fi
  done
}

# Main
case "${1:-}" in
  red|green|yellow)
    led_on "$1"
    ;;
  off)
    all_off
    echo "All LEDs OFF"
    ;;
  status)
    led_status
    ;;
  *)
    echo "Usage: $0 {red|green|yellow|off|status}" >&2
    exit 1
    ;;
esac
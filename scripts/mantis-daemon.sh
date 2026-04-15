#!/usr/bin/env bash
# mantis-daemon.sh — Hot path daemon runner
# Starts: pipes ave-cloud-cli wss-repl → signal-matcher.sh → gpio-control.sh
# Usage: mantis-daemon.sh {start|stop|restart|status}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${MANTIS_PID:-/var/run/mantis-reflexd.pid}"
LOG_FILE="${MANTIS_LOG:-/var/log/mantis-reflexd.log}"
SIGNAL_MATCHER="${SCRIPT_DIR}/signal-matcher.sh"
GPIO_CONTROL="${SCRIPT_DIR}/gpio-control.sh"

# Ensure required environment
check_env() {
  if [[ -z "${AVE_API_KEY:-}" ]]; then
    echo "ERROR: AVE_API_KEY not set" >&2
    exit 1
  fi
  if [[ "${API_PLAN:-pro}" != "pro" ]]; then
    echo "WARNING: API_PLAN is not 'pro' — WSS may not work" >&2
  fi
}

# Check if daemon is running
is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Start the daemon
do_start() {
  if is_running; then
    echo "mantis-reflexd already running (PID $(cat "$PID_FILE"))"
    return 0
  fi

  check_env

  # Ensure log directory exists
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

  # Ensure gpio-control is executable
  chmod +x "$GPIO_CONTROL" 2>/dev/null || true
  chmod +x "$SIGNAL_MATCHER" 2>/dev/null || true

  echo "Starting mantis-reflexd..."

  # Start the pipeline: wss-repl → signal-matcher → gpio-control
  # Run in background, redirect output to log
  nohup env AVE_API_KEY="$AVE_API_KEY" API_PLAN="${API_PLAN:-pro}" \
    ave-cloud-cli wss-repl 2>/dev/null | \
    "$SIGNAL_MATCHER" > "$LOG_FILE" 2>&1 &

  local pid=$!
  echo "$pid" > "$PID_FILE"

  sleep 1

  if is_running; then
    echo "mantis-reflexd started (PID $pid)"
    echo "Log: $LOG_FILE"
  else
    echo "ERROR: Failed to start mantis-reflexd" >&2
    rm -f "$PID_FILE"
    exit 1
  fi
}

# Stop the daemon
do_stop() {
  if ! is_running; then
    echo "mantis-reflexd is not running"
    rm -f "$PID_FILE" 2>/dev/null || true
    return 0
  fi

  local pid
  pid=$(cat "$PID_FILE")

  echo "Stopping mantis-reflexd (PID $pid)..."

  # Turn off all LEDs first
  "$GPIO_CONTROL" off 2>/dev/null || true

  # Kill the process
  kill "$pid" 2>/dev/null || true

  # Wait for graceful shutdown
  local count=0
  while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
    sleep 0.5
    count=$((count + 1))
  done

  # Force kill if still alive
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$PID_FILE"
  echo "mantis-reflexd stopped"
}

# Show daemon status
do_status() {
  if is_running; then
    local pid
    pid=$(cat "$PID_FILE")
    echo "mantis-reflexd is running (PID $pid)"
    echo "Log: $LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
      echo ""
      echo "--- Last 10 lines of log ---"
      tail -10 "$LOG_FILE"
    fi
  else
    echo "mantis-reflexd is not running"
    if [[ -f "$LOG_FILE" ]]; then
      echo ""
      echo "--- Last 10 lines of log ---"
      tail -10 "$LOG_FILE"
    fi
  fi
}

# Main
case "${1:-}" in
  start)
    do_start
    ;;
  stop)
    do_stop
    ;;
  restart)
    do_stop
    sleep 1
    do_start
    ;;
  status)
    do_status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}" >&2
    exit 1
    ;;
esac
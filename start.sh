set -euo pipefail

PORT=8080
INTERRUPT_SECONDS=""

usage() {
  echo "Usage: $0 [-p port] [-i seconds]"
}

while getopts ":p:i:h" opt; do
  case "$opt" in
    p) PORT="$OPTARG" ;;
    i) INTERRUPT_SECONDS="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG"; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument."; usage; exit 1 ;;
  esac
done

popup_seconds=5

show_alert() {
  local message="$1"
  local seconds="${2:-5}"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    /usr/bin/osascript <<EOF
display dialog "$message" with title "Notice" giving up after $seconds
EOF
    return
  fi

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -t $((seconds * 1000)) "Notice" "$message"
    return
  fi

  echo "$message"
}

cleanup() {
  if [[ -n "${HTTP_PID:-}" ]] && kill -0 "$HTTP_PID" 2>/dev/null; then
    kill "$HTTP_PID" 2>/dev/null || true
  fi
  if [[ -n "${NGROK_PID:-}" ]] && kill -0 "$NGROK_PID" 2>/dev/null; then
    kill "$NGROK_PID" 2>/dev/null || true
  fi
  echo "Done."
}

trap cleanup EXIT INT TERM

echo "Starting HTTP server on port $PORT"
http-server -p "$PORT" &
HTTP_PID=$!
echo "HTTP server started on port $PORT (PID $HTTP_PID)"

echo "Starting ngrok tunnel on port $PORT"
ngrok http "$PORT" &
NGROK_PID=$!
echo "ngrok tunnel started on port $PORT (PID $NGROK_PID)"

if [[ -n "$INTERRUPT_SECONDS" ]]; then
  echo "Will stop both processes after $INTERRUPT_SECONDS seconds. Press Ctrl+C to stop sooner."
else
  echo "Press Ctrl+C to stop both processes."
fi

start_time=$(date +%s)
alert_seconds=60
if [[ -n "$INTERRUPT_SECONDS" ]] && [[ "$INTERRUPT_SECONDS" -lt 60 ]]; then
  alert_seconds="$INTERRUPT_SECONDS"
fi
alerted=false

while true; do
  sleep 1
  now=$(date +%s)
  elapsed=$((now - start_time))

  if [[ "$alerted" == "false" ]] && [[ "$elapsed" -ge "$alert_seconds" ]]; then
    if [[ "$alert_seconds" -lt 60 ]]; then
      echo "Alert: $alert_seconds seconds elapsed."
      show_alert "$alert_seconds seconds elapsed." "$popup_seconds"
    else
      echo "Alert: 1 minute elapsed."
      show_alert "1 minute elapsed." "$popup_seconds"
    fi
    alerted=true
  fi

  if [[ -n "$INTERRUPT_SECONDS" ]] && [[ "$elapsed" -ge "$INTERRUPT_SECONDS" ]]; then
    echo "Interrupt timer reached. Stopping both processes."
    break
  fi

  if ! kill -0 "$HTTP_PID" 2>/dev/null || ! kill -0 "$NGROK_PID" 2>/dev/null; then
    echo "One of the processes exited. Stopping the other."
    break
  fi
done

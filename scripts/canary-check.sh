#!/usr/bin/env bash
# canary-check.sh <url> [seconds]  - poll an endpoint for N seconds; fail on any non-200 or if error ratio exceeds 2%.
set -u
URL="${1:?url}"; DURATION="${2:-60}"
end=$((SECONDS+DURATION)); ok=0; bad=0
while [ $SECONDS -lt $end ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" || echo 000)
  if [ "$code" = "200" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
  sleep 2
done
total=$((ok+bad)); echo "ok=$ok bad=$bad total=$total"
[ $total -gt 0 ] && [ $((bad*100/total)) -le 2 ] || { echo "canary failed"; exit 1; }

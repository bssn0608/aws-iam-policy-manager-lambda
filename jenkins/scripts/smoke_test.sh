#!/usr/bin/env bash
set -euo pipefail
if [ -n "${INVOKE_URL:-}" ]; then
  curl -sS "${INVOKE_URL}/user-access?userid=test-user&dry_run=true" | jq .
else
  aws lambda invoke --function-name test-user-access /tmp/out.json >/dev/null
  cat /tmp/out.json | jq .
fi

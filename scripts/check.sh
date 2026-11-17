#!/usr/bin/env bash
# Smoke alarm for the Open Indiana Law MCP. Exits non-zero (so the workflow fails and GitHub notifies the owner)
# if the health page, a real statute lookup or a real search fails. Retries 3 times to avoid one-off blips.
set -u
BASE="${OIL_BASE:-https://mcp.openindianalaw.org}"
H=(-H 'content-type: application/json' -H 'accept: application/json, text/event-stream')

check_once() {
  local out
  out=$(curl -fsS -m 20 "$BASE/health") || { echo "health request failed"; return 1; }
  echo "$out" | grep -q '"ok":true' || { echo "health not ok: $out"; return 1; }

  out=$(curl -fsS -m 40 -X POST "$BASE/mcp" "${H[@]}" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ic_get_section","arguments":{"section_id":"35-42-1-1"}}}') || { echo "ic_get_section request failed"; return 1; }
  echo "$out" | grep -q 'found\\": true' || { echo "ic_get_section did not find 35-42-1-1"; return 1; }
  echo "snapshot: $(echo "$out" | grep -o 'snapshot_id\\": \\"[0-9-]*' | head -1)"

  out=$(curl -fsS -m 60 -X POST "$BASE/mcp" "${H[@]}" -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ic_search","arguments":{"query":"habeas"}}}') || { echo "ic_search request failed"; return 1; }
  echo "$out" | grep -q '"isError":true' && { echo "ic_search returned an error"; return 1; }
  echo "$out" | grep -q -i 'section_id' || { echo "ic_search returned no sections"; return 1; }
  return 0
}

for attempt in 1 2 3; do
  if check_once; then echo "OK (attempt $attempt) at $(date -u +%FT%TZ)"; exit 0; fi
  echo "attempt $attempt failed; waiting"; sleep 20
done
echo "ALARM: Open Indiana Law check failed 3 times at $(date -u +%FT%TZ) against $BASE"
exit 1

#!/usr/bin/env bash
# critic-hook.sh — PreToolUse hook for discord_reply
#
# Thin gate: blocks substantive Discord messages unless the ruthless-critic
# agent has reviewed and approved them. The actual critique logic lives in
# ~/.claude/agents/ruthless-critic.md — this hook just validates the verdict file.
#
# Coordination chatter (<280 chars) passes unchecked.

set -euo pipefail

INPUT=$(cat)

# ── Extract message text ──
TEXT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    ti = data.get('tool_input', data.get('input', {}))
    if isinstance(ti, str):
        ti = json.loads(ti)
    print(ti.get('text', '') or ti.get('content', '') or ti.get('message', ''))
except:
    pass
" 2>/dev/null || true)

# ── Short messages are coordination — let them through ──
[ ${#TEXT} -lt 280 ] && exit 0

# ── Hash the exact message ──
HASH=$(printf '%s' "$TEXT" | shasum -a 256 | cut -c1-16)

REVIEW_DIR="${CRITIC_REVIEW_DIR:-.critic-reviews}"
REVIEW_FILE="${REVIEW_DIR}/${HASH}.json"

# ── Validate existing verdict ──
if [ -f "$REVIEW_FILE" ]; then
  RESULT=$(python3 -c "
import json, sys, os, time

with open(sys.argv[1]) as f:
    r = json.load(f)

h, v, rev, cats = r.get('message_hash',''), r.get('verdict','').strip().upper(), r.get('review',''), r.get('categories_checked',[])

if h != sys.argv[2]:          print('hash_mismatch')
elif v != 'APPROVE':          print('verdict_' + v.lower())
elif len(rev) < 80:           print('rubber_stamp_' + str(len(rev)) + '_chars')
elif len(cats) < 1:           print('lazy_review_' + str(len(cats)) + '_categories')
elif (time.time() - os.path.getmtime(sys.argv[1])) > 900:
                               print('stale_' + str(int((time.time() - os.path.getmtime(sys.argv[1]))/60)) + 'min')
else:                          print('PASS')
" "$REVIEW_FILE" "$HASH" 2>/dev/null || echo "parse_error")

  [ "$RESULT" = "PASS" ] && exit 0
  REASON="$RESULT"
else
  REASON="no_review"
fi

# ── BLOCK ──
mkdir -p "$REVIEW_DIR"

cat >&2 <<EOF
BLOCKED (critic-hook): ${REASON}

Your Discord message must survive the ruthless-critic before posting.

Spawn it now — use the Agent tool with subagent_type "ruthless-critic":

  Review this proposed Discord message and write your verdict.

  MESSAGE HASH: ${HASH}
  REVIEW FILE:  ${REVIEW_DIR}/${HASH}.json

  PROPOSED MESSAGE:
  ${TEXT}

After the critic runs:
  APPROVE → retry your Discord reply (this hook will let it through)
  REVISE  → fix every issue, then retry (new message = new hash = new review)
EOF
exit 2

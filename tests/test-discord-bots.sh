#!/usr/bin/env bash
# Verify all 5 research group Discord bots are alive and can communicate
set -euo pipefail
source ~/.kenoma-multi-agent.env

DISCORD_API="https://discord.com/api/v10"
ROLES=(pi senior-researcher research-assistant engineer theorist)
TOKENS=("$BOT_PI_TOKEN" "$BOT_SENIOR_TOKEN" "$BOT_ASSISTANT_TOKEN" "$BOT_ENGINEER_TOKEN" "$BOT_THEORIST_TOKEN")

PASS=0
FAIL=0
BOT_NAMES=()

echo "=== Research Group Bot Connectivity Test ==="
echo ""

# Test identity for each bot
for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  token="${TOKENS[$i]}"

  ME=$(curl -s -H "Authorization: Bot ${token}" "${DISCORD_API}/users/@me")
  NAME=$(echo "$ME" | jq -r '.username // empty')
  if [ -n "$NAME" ]; then
    echo "  ✓ ${role}: @${NAME}"
    BOT_NAMES+=("$NAME")
    ((PASS++))
  else
    echo "  ✗ ${role}: auth FAILED — $(echo "$ME" | jq -r '.message // "unknown"')"
    BOT_NAMES+=("")
    ((FAIL++))
  fi
done

echo ""

# Test send for each bot
for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  token="${TOKENS[$i]}"

  RESP=$(curl -s -X POST "${DISCORD_API}/channels/${DISCORD_CHANNEL_ID}/messages" \
    -H "Authorization: Bot ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"[test] ${role} checking in at $(date -u +%Y-%m-%dT%H:%M:%SZ)\"}")
  MSG_ID=$(echo "$RESP" | jq -r '.id // empty')
  if [ -n "$MSG_ID" ]; then
    echo "  ✓ ${role} can send (msg: ${MSG_ID})"
    ((PASS++))
  else
    echo "  ✗ ${role} send FAILED — $(echo "$RESP" | jq -r '.message // "unknown"')"
    ((FAIL++))
  fi
done

echo ""

# Test cross-visibility: PI reads channel history and checks if it can see other bots
echo "Testing cross-bot visibility..."
HIST=$(curl -s -H "Authorization: Bot ${BOT_PI_TOKEN}" "${DISCORD_API}/channels/${DISCORD_CHANNEL_ID}/messages?limit=10")
HIST_COUNT=$(echo "$HIST" | jq 'length')

if [ "$HIST_COUNT" -gt 0 ]; then
  echo "  ✓ PI can read history (${HIST_COUNT} messages)"
  ((PASS++))

  # Check if PI can see messages from other bots
  for j in 1 2 3 4; do
    other_name="${BOT_NAMES[$j]}"
    if [ -n "$other_name" ]; then
      SEES=$(echo "$HIST" | jq "[.[] | select(.author.username == \"${other_name}\")] | length")
      if [ "$SEES" -gt 0 ]; then
        echo "  ✓ PI sees ${ROLES[$j]}'s messages"
        ((PASS++))
      else
        echo "  ⚠ PI doesn't see ${ROLES[$j]} in recent history"
      fi
    fi
  done
else
  echo "  ✗ PI can't read history"
  ((FAIL++))
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: Some tests failed. Check bot tokens and channel ID."
  exit 1
else
  echo "PASS: All bots verified."
  exit 0
fi

#!/usr/bin/env bash
# Send a research directive to the Discord channel to test the research group
set -euo pipefail
source ~/.kenoma-multi-agent.env

DISCORD_API="https://discord.com/api/v10"

# Send as plain text (human directive) — PI should pick this up
DIRECTIVE="I want the team to investigate optimal hash table load factors for cache efficiency on modern x86 hardware. Specifically:

1. Survey existing literature on hash table performance vs load factor
2. Design and run an experiment comparing load factors 0.5, 0.7, and 0.9
3. If we find a clear optimum, see if we can prove a theoretical bound

PI: decompose this and assign work to the team."

echo "=== Research Group Collaboration Test ==="
echo ""
echo "Sending research directive to Discord channel..."

# Send via the last bot token (theorist) so PI will see it
# (PI filters its own messages, so we can't send from PI's token)
RESP=$(curl -s -X POST "${DISCORD_API}/channels/${DISCORD_CHANNEL_ID}/messages" \
  -H "Authorization: Bot ${BOT_THEORIST_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg content "$DIRECTIVE" '{content: $content}')")

MSG_ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -n "$MSG_ID" ]; then
  echo "✓ Directive sent (msg: ${MSG_ID})"
else
  echo "✗ Failed to send: $(echo "$RESP" | jq -r '.message // "unknown"')"
  exit 1
fi

echo ""
echo "Expected flow:"
echo "  1. PI receives directive, decomposes into research questions"
echo "  2. PI assigns survey to Research Assistant"
echo "  3. PI assigns experiment design to Senior Researcher"
echo "  4. PI requests benchmarking tool from Engineer"
echo "  5. PI assigns theoretical verification to Theorist"
echo "  6. Agents execute phases via orchestration-kit tools/kit"
echo "  7. Results flow back through PI"
echo "  8. PI synthesizes and reports to human in Discord"
echo ""
echo "Monitor progress:"
echo "  - Discord #agent-collab channel"
echo "  - tmux attach -t research-group"
echo "  - tail -f logs/*.log"

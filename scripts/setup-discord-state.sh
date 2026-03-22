#!/usr/bin/env bash
# Creates Discord state directories for all 5 research group agents
set -euo pipefail
source ~/.kenoma-multi-agent.env

ROLES=(pi senior-researcher research-assistant engineer theorist)
TOKENS=("$BOT_PI_TOKEN" "$BOT_SENIOR_TOKEN" "$BOT_ASSISTANT_TOKEN" "$BOT_ENGINEER_TOKEN" "$BOT_THEORIST_TOKEN")
CHANNEL_ID="$DISCORD_CHANNEL_ID"

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  token="${TOKENS[$i]}"
  state_dir="$HOME/.claude/channels/discord-${role}"

  mkdir -p "$state_dir"

  echo "DISCORD_BOT_TOKEN=${token}" > "${state_dir}/.env"
  chmod 600 "${state_dir}/.env"

  cat > "${state_dir}/access.json" <<EOF
{
  "dmPolicy": "allowlist",
  "allowFrom": [],
  "groups": {
    "${CHANNEL_ID}": {
      "requireMention": false,
      "allowFrom": []
    }
  },
  "ackReaction": "",
  "replyToMode": "first",
  "textChunkLimit": 2000,
  "chunkMode": "newline"
}
EOF

  echo "Configured: ${role} → ${state_dir}"
done

echo ""
echo "All 5 state dirs created. Verify with:"
echo "  ls ~/.claude/channels/discord-*/"

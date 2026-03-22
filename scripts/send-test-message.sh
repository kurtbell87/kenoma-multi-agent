#!/usr/bin/env bash
# Send a raw message to the Discord channel to test connectivity
source ~/.kenoma-multi-agent.env

MESSAGE=${1:-"ping from bootstrapper"}

curl -s -X POST "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" \
  -H "Authorization: Bot ${BOT_PI_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"${MESSAGE}\"}" | jq '{id: .id, content: .content, author: .author.username}'

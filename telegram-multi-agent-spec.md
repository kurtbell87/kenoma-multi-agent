# Multi-Agent Claude Code Collaboration via Telegram

## Overview

Build a scaffold that enables two Claude Code instances to collaborate on tasks by communicating through a Telegram group chat, using the Claude Code Channels feature (research preview, v2.1.80+). A third bootstrapper instance (you) sets everything up, spawns the agents, and runs validation.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  tmux session: "multi-agent"                        │
│                                                     │
│  ┌─────────┐   ┌──────────┐   ┌──────────┐        │
│  │ pane 0  │   │ pane 1   │   │ pane 2   │        │
│  │ monitor │   │ Agent A  │   │ Agent B  │        │
│  │ (logs)  │   │ claude   │   │ claude   │        │
│  │         │   │ --chan    │   │ --chan   │        │
│  └────┬────┘   └────┬─────┘   └────┬─────┘        │
│       │              │              │               │
└───────┼──────────────┼──────────────┼───────────────┘
        │              │              │
        │         ┌────▼──────────────▼────┐
        │         │  Telegram Group Chat   │
        │         │  "@kenoma_collab"       │
        │         │                        │
        │         │  BotA ◄──► BotB        │
        │         │    ▲                   │
        │         │    │ (human can also   │
        │         │    │  observe/inject)  │
        └────────►│    ▼                   │
                  └────────────────────────┘
```

## Prerequisites (human must do before running bootstrap)

1. **Create two Telegram bots** via @BotFather:
   - `/newbot` → name: `Kenoma Agent A` → username: anything → save token as `BOT_A_TOKEN`
   - `/newbot` → name: `Kenoma Agent B` → username: anything → save token as `BOT_B_TOKEN`
   - For each bot: `/setprivacy` → select bot → `Disable` (so bots can read group messages)

2. **Create a Telegram group**:
   - Create new group, name it whatever
   - Add both bots to the group
   - Send at least one message in the group (activates it)
   - Get the group chat ID. Easiest method: add `@raw_data_bot` to group, it prints the chat ID, then remove it. Save as `GROUP_CHAT_ID`.

3. **Environment**: Claude Code v2.1.80+, Bun installed, tmux installed, claude.ai login active.

4. **Create env file** at `~/.kenoma-multi-agent.env`:
   ```
   BOT_A_TOKEN=<token from BotFather>
   BOT_B_TOKEN=<token from BotFather>
   GROUP_CHAT_ID=<negative number from step 2>
   ```

## Project Structure to Build

```
kenoma-multi-agent/
├── CLAUDE.md                    # Root instructions (for bootstrapper)
├── protocol/
│   ├── MESSAGE_SCHEMA.md        # Wire protocol for inter-agent messages
│   └── COORDINATION.md          # Turn-taking, task handoff, termination
├── agents/
│   ├── agent-a/
│   │   ├── CLAUDE.md            # Agent A role, instructions, protocol
│   │   └── workspace/           # Agent A working directory
│   └── agent-b/
│       ├── CLAUDE.md            # Agent B role, instructions, protocol
│       └── workspace/           # Agent B working directory
├── scripts/
│   ├── bootstrap.sh             # Sets up tmux, configures channels, spawns agents
│   ├── teardown.sh              # Kills tmux session, cleans up
│   ├── send-test-message.sh     # Sends a message to group via curl (for testing)
│   └── monitor.sh               # Tails logs from both agents
├── tests/
│   ├── test-telegram-bots.sh    # Verify both bots can send/receive in group
│   ├── test-echo-loop.sh        # Send msg to group, verify both agents see it
│   └── test-collaboration.sh    # End-to-end: assign task, verify handoff + result
└── logs/
    ├── agent-a.log
    └── agent-b.log
```

## Phase 1: Build the Protocol

### MESSAGE_SCHEMA.md

All inter-agent messages in the Telegram group MUST be JSON wrapped in a code fence so agents can parse them reliably. Human messages (no code fence) are treated as directives/overrides.

```json
{
  "protocol": "kenoma-multi-agent-v1",
  "from": "agent-a",
  "to": "agent-b",
  "type": "task_handoff | result | question | status | ack | terminate",
  "task_id": "uuid-string",
  "payload": {
    "description": "free text or structured data",
    "files": ["list of file paths if relevant"],
    "context": "any context the receiving agent needs"
  },
  "seq": 1,
  "timestamp": "ISO-8601"
}
```

Message types:
- `task_handoff`: "Here's work for you to do." Receiver must `ack` before starting.
- `result`: "Here's the output of the task you gave me." Contains deliverable.
- `question`: "I need clarification." Blocks until answered.
- `status`: "Progress update, no action needed."
- `ack`: "I received your message and am working on it."
- `terminate`: "Collaboration complete. Both agents should stop."

### COORDINATION.md

Rules:
1. **No simultaneous sends.** After sending a message, wait for `ack` before sending another. This prevents race conditions.
2. **Sequence numbers are per-agent.** Agent A maintains its own seq counter, Agent B its own. Used to detect missed messages.
3. **Timeout.** If no `ack` within 60 seconds, resend once. If still no `ack`, send `status` with `"payload": {"error": "timeout"}` and wait for human intervention.
4. **Termination.** Either agent can propose `terminate`. Both must `ack` it. Bootstrapper monitor watches for dual-ack termination.
5. **Human override.** Any non-JSON message in the group is a human directive. Both agents pause, read it, and adjust. If it starts with `@agent-a` or `@agent-b`, only that agent acts on it.
6. **Shared filesystem.** Both agents can read/write to a shared directory (`kenoma-multi-agent/shared/`). Use this for large artifacts instead of stuffing them into Telegram messages. Reference files by path in the `files` field.

## Phase 2: Build the Agent CLAUDE.md Files

### agents/agent-a/CLAUDE.md

```markdown
# Agent A — Kenoma Multi-Agent Collaboration

You are Agent A in a two-agent collaboration system. You communicate with Agent B
through a Telegram group chat using the Kenoma multi-agent protocol.

## Your Identity
- Name: agent-a
- You send messages by replying in the Telegram channel
- You receive messages as channel events

## Protocol
- ALL messages to Agent B must be valid JSON in a code fence (triple backticks)
- Follow the schema in /path/to/protocol/MESSAGE_SCHEMA.md
- Follow coordination rules in /path/to/protocol/COORDINATION.md
- Increment your seq counter with each message you send
- Always ack received task_handoff and terminate messages

## Parsing Incoming Messages
- If a channel event contains a JSON code fence with "protocol": "kenoma-multi-agent-v1":
  → Parse it as an inter-agent message. Act according to type.
- If a channel event is plain text (no code fence):
  → This is a human directive. Read and comply.
- If a channel event is from yourself (from: "agent-a"):
  → Ignore it (echo suppression).

## Working Directory
- Your workspace: agents/agent-a/workspace/
- Shared space: shared/
- Write large artifacts to shared/, reference by path in messages.

## Current Task Assignment
[BOOTSTRAPPER FILLS THIS IN AT SPAWN TIME]
```

### agents/agent-b/CLAUDE.md — Mirror of above with identity swapped.

## Phase 3: Build the Scripts

### bootstrap.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

source ~/.kenoma-multi-agent.env

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMUX_SESSION="multi-agent"

# Validate prerequisites
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found"; exit 1; }
command -v bun >/dev/null 2>&1 || { echo "bun not found"; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "tmux not found"; exit 1; }

# Verify Claude Code version
CC_VERSION=$(claude --version 2>&1 | head -1)
echo "Claude Code version: $CC_VERSION"

# Install telegram plugin if not already installed
claude /plugin install telegram@claude-plugins-official 2>/dev/null || true

# Configure bot tokens for each agent
# Agent A config
mkdir -p ~/.claude/channels/agent-a-telegram
echo "TELEGRAM_BOT_TOKEN=${BOT_A_TOKEN}" > ~/.claude/channels/agent-a-telegram/.env

# Agent B config
mkdir -p ~/.claude/channels/agent-b-telegram
echo "TELEGRAM_BOT_TOKEN=${BOT_B_TOKEN}" > ~/.claude/channels/agent-b-telegram/.env

# Create tmux session
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
tmux new-session -d -s "$TMUX_SESSION" -n "monitor"

# Pane 0: monitor (stays as default)
tmux send-keys -t "$TMUX_SESSION:0" "echo 'Monitor pane ready. Tailing logs...'" Enter
tmux send-keys -t "$TMUX_SESSION:0" "tail -f ${PROJECT_DIR}/logs/agent-*.log 2>/dev/null || echo 'Waiting for logs...'" Enter

# Pane 1: Agent A
tmux split-window -h -t "$TMUX_SESSION:0"
tmux send-keys -t "$TMUX_SESSION:0.1" "cd ${PROJECT_DIR}/agents/agent-a && TELEGRAM_BOT_TOKEN=${BOT_A_TOKEN} claude --channels plugin:telegram@claude-plugins-official 2>&1 | tee ${PROJECT_DIR}/logs/agent-a.log" Enter

# Pane 2: Agent B
tmux split-window -v -t "$TMUX_SESSION:0.1"
tmux send-keys -t "$TMUX_SESSION:0.2" "cd ${PROJECT_DIR}/agents/agent-b && TELEGRAM_BOT_TOKEN=${BOT_B_TOKEN} claude --channels plugin:telegram@claude-plugins-official 2>&1 | tee ${PROJECT_DIR}/logs/agent-b.log" Enter

echo ""
echo "=== Multi-agent session launched ==="
echo "Attach with: tmux attach -t $TMUX_SESSION"
echo ""
echo "Next steps:"
echo "  1. Pair each bot in Telegram (DM each bot, get pairing code)"
echo "  2. Run: ./scripts/test-telegram-bots.sh"
echo "  3. Send a task to the group chat"
```

### send-test-message.sh

```bash
#!/usr/bin/env bash
# Send a raw message to the Telegram group to test connectivity
source ~/.kenoma-multi-agent.env

MESSAGE=${1:-"ping from bootstrapper"}
BOT_TOKEN=${BOT_A_TOKEN}  # Use either bot to send

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${GROUP_CHAT_ID}\", \"text\": \"${MESSAGE}\"}" | jq .
```

### teardown.sh

```bash
#!/usr/bin/env bash
tmux kill-session -t "multi-agent" 2>/dev/null && echo "Session killed" || echo "No session found"
```

## Phase 4: Test Harness

### test-telegram-bots.sh

```bash
#!/usr/bin/env bash
# Verify both bots are alive and can post to the group
source ~/.kenoma-multi-agent.env

echo "Testing Bot A..."
RESP_A=$(curl -s -X POST "https://api.telegram.org/bot${BOT_A_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${GROUP_CHAT_ID}\", \"text\": \"[test] Agent A checking in\"}")
echo "$RESP_A" | jq -r '.ok'

echo "Testing Bot B..."
RESP_B=$(curl -s -X POST "https://api.telegram.org/bot${BOT_B_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${GROUP_CHAT_ID}\", \"text\": \"[test] Agent B checking in\"}")
echo "$RESP_B" | jq -r '.ok'

# Verify bots can read (getUpdates)
echo "Bot A recent updates:"
curl -s "https://api.telegram.org/bot${BOT_A_TOKEN}/getUpdates?limit=1" | jq '.result | length'

echo "Bot B recent updates:"
curl -s "https://api.telegram.org/bot${BOT_B_TOKEN}/getUpdates?limit=1" | jq '.result | length'
```

### test-collaboration.sh

```bash
#!/usr/bin/env bash
# End-to-end test: send a collaboration task to the group, verify handoff
source ~/.kenoma-multi-agent.env

TASK_ID=$(uuidgen || python3 -c "import uuid; print(uuid.uuid4())")

# Send a task that requires both agents
TASK_MSG=$(cat <<EOF
\`\`\`json
{
  "protocol": "kenoma-multi-agent-v1",
  "from": "human",
  "to": "agent-a",
  "type": "task_handoff",
  "task_id": "${TASK_ID}",
  "payload": {
    "description": "Write a Python function that computes the first N Fibonacci numbers. Then hand off to agent-b to write unit tests for it. Agent B: write tests, run them, report results.",
    "files": [],
    "context": "This is a validation test of the multi-agent collaboration protocol. Keep it simple."
  },
  "seq": 0,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
\`\`\`
EOF
)

echo "Sending collaboration task..."
curl -s -X POST "https://api.telegram.org/bot${BOT_A_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg chat_id "$GROUP_CHAT_ID" --arg text "$TASK_MSG" '{chat_id: $chat_id, text: $text}')" | jq .ok

echo ""
echo "Task sent. Monitor the Telegram group and agent logs."
echo "Expected flow:"
echo "  1. Agent A acks the task"
echo "  2. Agent A writes fibonacci.py to shared/"
echo "  3. Agent A sends task_handoff to Agent B with file reference"
echo "  4. Agent B acks"
echo "  5. Agent B writes + runs tests"
echo "  6. Agent B sends result"
echo "  7. Either agent sends terminate"
```

## Phase 5: Bootstrapper Execution Plan

When the bootstrapper Claude Code instance receives this spec, it should:

1. **Create the project directory structure** exactly as specified above.
2. **Write all files** — protocol docs, CLAUDE.md files, scripts, test harnesses.
3. **Run `test-telegram-bots.sh`** to verify the bots are configured and can post. If this fails, stop and report.
4. **Run `bootstrap.sh`** to spawn the tmux session with both agents.
5. **Wait 30 seconds** for agents to initialize and pair.
6. **Run `test-collaboration.sh`** to send the end-to-end validation task.
7. **Monitor logs** for 2-3 minutes, watching for the expected message flow.
8. **Report results**: which steps succeeded, where it broke, what the agents actually said.

## Known Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Channels plugin rejects custom config paths | Fall back to single-plugin install, swap tokens between runs |
| Both bots see each other's messages AND their own | JSON `from` field enables echo suppression in CLAUDE.md |
| Infinite loop (A responds to B responds to A...) | Sequence numbers + `terminate` type + max_seq ceiling (e.g., 20) |
| Pairing flow blocks automation | Human does pairing manually before test-collaboration runs |
| Channel events don't include group context | Bot privacy mode must be disabled (prereq step) |
| Two claude sessions compete for same plugin config | Separate TELEGRAM_BOT_TOKEN env vars per shell |

## Configuration Notes for Channels

The Telegram channel plugin reads `TELEGRAM_BOT_TOKEN` from either:
1. Shell environment variable (takes precedence)
2. `~/.claude/channels/telegram/.env`

Since we need two different tokens, we set the token as a shell env var per-pane in tmux, so each Claude Code session picks up its own bot identity. If the plugin doesn't respect per-shell env vars and only reads from the dotfile, the fallback is to run them sequentially (configure bot A, test, teardown, configure bot B, test) rather than concurrently. That's a known limitation of the research preview.
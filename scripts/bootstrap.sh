#!/usr/bin/env bash
set -euo pipefail

source ~/.kenoma-multi-agent.env

SCAFFOLD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ORCHESTRATION_KIT_DIR="/Users/brandonbell/LOCAL_DEV/orchestration-kit"
TMUX_SESSION="research-group"

# Project directory for this investigation
PROJECT_DIR="${1:-/Users/brandonbell/LOCAL_DEV/research-projects/hash-table-investigation}"

ROLES=(pi senior-researcher engineer theorist strategist surveyor)
TOKENS=("$BOT_PI_TOKEN" "$BOT_SENIOR_TOKEN" "$BOT_ENGINEER_TOKEN" "$BOT_THEORIST_TOKEN" "$BOT_STRATEGIST_TOKEN" "$BOT_SURVEYOR_TOKEN")

# Which kit each role uses (empty = no kit)
KIT_DIRS=("" "research-kit" "tdd-kit" "mathematics-kit" "" "research-kit")

# Extra --add-dir flags per role (e.g., reference docs)
# All agents get the reference symlink (options-tail-risk-scanner repo)
EXTRA_DIRS=("${PROJECT_DIR}/reference" "${PROJECT_DIR}/reference" "${PROJECT_DIR}/reference" "${PROJECT_DIR}/reference" "${PROJECT_DIR}/reference" "${PROJECT_DIR}/reference")

# Validate prerequisites
for cmd in claude bun tmux; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd not found"; exit 1; }
done

# Verify orchestration-kit exists (for kit methodology CLAUDE.md files)
if [ ! -d "${ORCHESTRATION_KIT_DIR}" ]; then
  echo "ERROR: orchestration-kit not found at ${ORCHESTRATION_KIT_DIR}"
  exit 1
fi

# Verify all Discord state dirs exist
for role in "${ROLES[@]}"; do
  STATE_DIR="$HOME/.claude/channels/discord-${role}"
  if [ ! -f "${STATE_DIR}/.env" ] || [ ! -f "${STATE_DIR}/access.json" ]; then
    echo "ERROR: Discord state dir not configured for ${role}."
    echo "  Run: ./scripts/setup-discord-state.sh"
    exit 1
  fi
done

CC_VERSION=$(claude --version 2>&1 | head -1)
echo "Claude Code version: $CC_VERSION"
echo "Project directory: $PROJECT_DIR"

# Create project directory structure
mkdir -p "${PROJECT_DIR}/shared"/{surveys,experiments,proofs,tools}
mkdir -p "${PROJECT_DIR}/logs"

# Create per-agent workspaces
for role in "${ROLES[@]}"; do
  mkdir -p "${PROJECT_DIR}/${role}"
done

# Create tmux session — 2 windows, 3 agents each
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

# Window 0 (team-a): PI, Senior Researcher, Engineer
tmux new-session -d -s "$TMUX_SESSION" -n "team-a"
tmux split-window -h -t "$TMUX_SESSION:team-a"
tmux split-window -v -t "$TMUX_SESSION:team-a.0"

# Window 1 (team-b): Theorist, Strategist, Surveyor
tmux new-window -t "$TMUX_SESSION" -n "team-b"
tmux split-window -h -t "$TMUX_SESSION:team-b"
tmux split-window -v -t "$TMUX_SESSION:team-b.0"

# Map: role index → window:pane
PANE_MAP=(
  "team-a.0"   # pi
  "team-a.1"   # senior-researcher
  "team-a.2"   # engineer
  "team-b.0"   # theorist
  "team-b.1"   # strategist
  "team-b.2"   # surveyor
)

# Generate and launch per-agent launchers
LAUNCHER_DIR="${SCAFFOLD_DIR}/.launchers"
mkdir -p "$LAUNCHER_DIR"

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  token="${TOKENS[$i]}"
  state_dir="$HOME/.claude/channels/discord-${role}"
  kit_dir="${KIT_DIRS[$i]}"
  pane="${PANE_MAP[$i]}"
  workspace="${PROJECT_DIR}/${role}"

  # Build --add-dir flags
  ADD_DIRS="--add-dir ${SCAFFOLD_DIR}/agents/${role}"
  ADD_DIRS="${ADD_DIRS} --add-dir ${PROJECT_DIR}/shared"

  # Add kit methodology CLAUDE.md if this role has a kit
  if [ -n "$kit_dir" ]; then
    ADD_DIRS="${ADD_DIRS} --add-dir ${ORCHESTRATION_KIT_DIR}/${kit_dir}"
  fi

  # Add any extra dirs for this role
  extra_dir="${EXTRA_DIRS[$i]}"
  if [ -n "$extra_dir" ]; then
    ADD_DIRS="${ADD_DIRS} --add-dir ${extra_dir}"
  fi

  cat > "${LAUNCHER_DIR}/${role}.sh" <<LAUNCHER
#!/usr/bin/env bash
cd ${workspace}
export DISCORD_BOT_TOKEN='${token}'
export DISCORD_STATE_DIR='${state_dir}'
exec claude --model 'claude-opus-4-6[1m]' --dangerously-skip-permissions ${ADD_DIRS} --channels plugin:discord@claude-plugins-official
LAUNCHER
  chmod +x "${LAUNCHER_DIR}/${role}.sh"

  tmux send-keys -t "$TMUX_SESSION:${pane}" "${LAUNCHER_DIR}/${role}.sh" Enter
done

# Wait for Claude Code instances to start, then activate remote control
echo "Waiting for agents to start..."
sleep 10

for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  pane="${PANE_MAP[$i]}"
  tmux send-keys -t "$TMUX_SESSION:${pane}" "/rename opra-${role}" Enter
  sleep 0.5
  tmux send-keys -t "$TMUX_SESSION:${pane}" "/rc" Enter
  sleep 0.5
done

echo "Remote control activated for all agents."

# Wait for agents to connect, then post status messages
echo "Waiting for agents to connect..."
sleep 8

DISPLAY_NAMES=(
  "Kenoma PI"
  "Kenoma Senior Researcher"
  "Kenoma Engineer"
  "Kenoma Theorist"
  "Kenoma Critical Strategist"
  "Kenoma Surveyor"
)

for i in "${!ROLES[@]}"; do
  token="${TOKENS[$i]}"
  name="${DISPLAY_NAMES[$i]}"
  curl -s -X POST \
    -H "Authorization: Bot ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"**${name}** online. Ready to rumble.\"}" \
    "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" > /dev/null
  sleep 0.3
done

echo ""
echo "=== Research Group launched ==="
echo "Attach with: tmux attach -t $TMUX_SESSION"
echo ""
echo "Project: ${PROJECT_DIR}"
echo "Shared:  ${PROJECT_DIR}/shared/"
echo ""
echo "Agents:"
for i in "${!ROLES[@]}"; do
  role="${ROLES[$i]}"
  kit="${KIT_DIRS[$i]:-"(coordinator)"}"
  echo "  ${role} → workspace: ${PROJECT_DIR}/${role}/ | kit: ${kit}"
done
echo ""
echo "Kit methodology sourced from: ${ORCHESTRATION_KIT_DIR}"
echo "Agent instructions from: ${SCAFFOLD_DIR}/agents/"
echo ""
echo "Send a research directive in Discord or run ./tests/test-collaboration.sh"

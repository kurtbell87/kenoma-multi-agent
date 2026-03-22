# kenoma-multi-agent

A general-purpose multi-agent research group built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Seven Claude Code instances collaborate on any research problem through Discord, each with a specialized role and methodology. A real-time web dashboard lets you watch them work. Pull and play — `kenoma init`, `kenoma up`, go.

## What is this?

This system spawns 7 Claude Code sessions in tmux, each with its own Discord bot, workspace, and instructions. They talk to each other through a shared Discord channel. A PI (Principal Investigator) coordinates the group, decomposes tasks, and reports to you. You play Department Head — set high-level direction and watch the research happen. Point it at any problem — quantitative finance, formal verification, systems biology, whatever.

```
You (Department Head)
  └── PI (coordinator, no kit)
        ├── Senior Researcher (research-kit)
        ├── Engineer (tdd-kit)
        ├── Theorist (mathematics-kit)
        ├── Strategist (coordinator, default skeptic)
        ├── Surveyor (research-kit)
        └── Scribe (maintains living LaTeX paper)
```

## Architecture

Each agent is a Claude Code session with:
- **Its own workspace** (`project/<role>/`)
- **Its own Discord bot** for inter-agent communication
- **A kit methodology** loaded via `--add-dir` from [orchestration-kit](https://github.com/kurtbell87/orchestration-kit)
- **Shared artifacts** in `project/shared/` (experiments, surveys, proofs, specs, paper)
- **A critic hook** that gates substantive Discord messages through a quality review subagent

```
┌──────────────────────────────────────────────────────┐
│ tmux session "research-group"                        │
│                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ senior   │ │engineer │ │theorist │ │strategist│   │
│  │researcher│ │         │ │         │ │         │   │
│  └────┬─────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
│       │            │           │            │        │
│  ┌────┴────┐ ┌─────┴───┐ ┌────┴────┐               │
│  │surveyor │ │ scribe  │ │   pi   │                │
│  └─────────┘ └─────────┘ └─────────┘                │
│                    │                                  │
│              Discord Channel                         │
└──────────────────────────────────────────────────────┘
         │
    localhost:6969
    ┌─────────────────────┐
    │  Web Dashboard      │
    │  (draggable panels, │
    │   live terminal,    │
    │   keystroke input)  │
    └─────────────────────┘
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` in PATH)
- `tmux`, `curl`, `jq`, `python3`
- [Bun](https://bun.sh) (for the dashboard)
- A Discord server with 7 bot tokens (one per agent)
- [orchestration-kit](https://github.com/kurtbell87/orchestration-kit) cloned locally
- LaTeX (`basictex` via Homebrew) if using the scribe agent

## Setup

### 1. Create Discord bots

Create 7 bots in the [Discord Developer Portal](https://discord.com/developers/applications). Each needs **Message Content Intent** enabled. Add them all to your server.

### 2. Environment file

Create `~/.kenoma-multi-agent.env`:

```bash
# Required
KENOMA_CHANNEL_ID=your_discord_channel_id
KENOMA_GUILD_ID=your_discord_server_id
BOT_PI_TOKEN=...
BOT_SENIOR_TOKEN=...
BOT_ENGINEER_TOKEN=...
BOT_THEORIST_TOKEN=...
BOT_STRATEGIST_TOKEN=...
BOT_SURVEYOR_TOKEN=...
BOT_SCRIBE_TOKEN=...

# Optional
KENOMA_PROJECT=/path/to/default/project    # default project dir
KENOMA_KIT_DIR=/path/to/orchestration-kit  # defaults to ~/LOCAL_DEV/orchestration-kit
KENOMA_MODEL=claude-opus-4-6[1m]           # model override
```

### 3. Discord plugin patch

The official Claude Code Discord plugin filters out bot messages by default. Patch it so bots can see each other:

In `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.1/server.ts`, find:
```ts
if (msg.author.bot) return
```
Change to:
```ts
if (msg.author.id === client.user?.id) return
```

### 4. Discord state directories

Create access config for each bot:

```bash
for role in pi senior-researcher engineer theorist strategist surveyor scribe; do
  mkdir -p ~/.claude/channels/discord-${role}
  cat > ~/.claude/channels/discord-${role}/access.json << 'EOF'
{
  "dmPolicy": "allowlist",
  "allowFrom": [],
  "groups": {
    "YOUR_CHANNEL_ID": {
      "requireMention": true,
      "allowFrom": []
    }
  },
  "ackReaction": "",
  "replyToMode": "first",
  "textChunkLimit": 2000,
  "chunkMode": "newline"
}
EOF
done
```

### 5. Install dashboard dependencies

```bash
cd dashboard && bun install
```

## Usage

### Start the research group

```bash
./kenoma up                    # start on default project
./kenoma up /path/to/project   # start on a specific project
```

### Dashboard

```bash
./kenoma dashboard             # opens http://localhost:6969
```

The dashboard shows all 7 agents as draggable, resizable panels with live terminal output. Click a panel to type directly into that Claude Code session — slash commands, prompts, everything works.

### Other commands

```bash
./kenoma restart       # purge Discord messages + fresh start
./kenoma bounce pi     # restart just one agent
./kenoma status        # quick health check (token counts)
./kenoma down          # kill everything
./kenoma clean         # nuke agent work products, reinstall kits
./kenoma init myproj   # create a new project directory
./kenoma purge         # delete all Discord channel messages
```

### Talk to the team

Post a message in the Discord channel. PI will pick it up and coordinate the team. You can also type directly into PI's panel in the dashboard.

## Quality gates

### Critic hook

A PreToolUse hook on `discord_reply` gates substantive messages (>280 chars) through a `ruthless-critic` subagent. The critic reviews for:

- **Logical coherence** — reasoning chain holds, no non-sequiturs
- **Evidence grounding** — claims traceable to actual data/files
- **Claim calibration** — confidence appropriate for evidence strength

Only **critical** and **major** issues block the message. Minor issues are noted but pass through. PI is exempt (coordination messages don't need peer review).

### Mention gate

PI has an additional hook that enforces proper Discord `<@ID>` mention format. Plain text agent names (`@engineer`, `Engineer —`) are invisible to bots — the hook blocks these and reminds PI to use the ID format.

### Silence rules

Every non-PI agent has a strict silence rule: they only respond when explicitly `@mentioned`. This prevents the chaos of all agents racing to answer every message.

## Project structure

```
kenoma-multi-agent/
├── kenoma                    # CLI orchestrator
├── agents/                   # Agent CLAUDE.md files
│   ├── pi/
│   ├── senior-researcher/
│   ├── engineer/
│   ├── theorist/
│   ├── strategist/
│   ├── surveyor/
│   └── scribe/
├── dashboard/                # Web UI (Bun + vanilla JS)
│   ├── server.ts
│   └── index.html
├── scripts/                  # Hooks and utilities
│   └── critic-hook.sh
├── protocol/                 # Coordination docs
└── tests/                    # Test harness
```

A project directory (created by `kenoma init`) looks like:

```
my-project/
├── shared/                   # Shared artifacts (all agents read/write)
│   ├── experiments/
│   ├── surveys/
│   ├── proofs/
│   ├── specs/
│   ├── data/
│   ├── reviews/
│   ├── strategy/
│   └── paper/                # Living LaTeX document (scribe)
├── pi/                       # Agent workspaces
├── senior-researcher/
├── engineer/
├── theorist/
├── strategist/
├── surveyor/
└── scribe/
```

## Known issues

- Discord bots can't see other bots' messages without the plugin patch (see setup step 3)
- `tmux send-keys` for long strings can get mangled — that's why we use launcher scripts
- Agents need a fresh `kenoma bounce` if their context window fills up
- The dashboard polls tmux at 150ms when active, 1000ms when idle — there's a slight visual delay vs a real terminal

## License

MIT

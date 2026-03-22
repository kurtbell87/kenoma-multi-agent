# CLAUDE.md — Kenoma Multi-Agent Research Group

This repo is the orchestration scaffold for a 7-agent Claude Code research group. It is **substrate-agnostic** — the tooling works for any research problem. Problem-specific context belongs in the project directory, not here.

## Quick Start

```bash
kenoma init /path/to/my-project    # create project workspace
kenoma up /path/to/my-project      # launch all 7 agents
kenoma dashboard                   # open web UI at localhost:6969
```

## Key Files

- `kenoma` — CLI orchestrator (up, down, restart, bounce, status, dashboard, etc.)
- `agents/<role>/CLAUDE.md` — Per-agent instructions and silence rules
- `dashboard/` — Real-time web dashboard (Bun + vanilla JS)
- `scripts/critic-hook.sh` — Quality gate hook for Discord messages
- `protocol/` — Coordination protocol docs

## Important Constraints

- `~/.kenoma-multi-agent.env` must exist with all 8 bot tokens before running `kenoma up`
- The Discord plugin patch (bot-to-bot visibility) must be applied — see README
- All scripts must be idempotent — safe to run multiple times
- Do not modify anything in `~/.claude/` without checking current state first
- PI spawns last — do not change the agent order in ROLES array

## Style

- Bash for scripts (no Python unless needed for JSON manipulation)
- Minimal dependencies — curl, jq, tmux, bun, claude CLI
- Fail fast with clear error messages
- Keep tooling general — no problem-specific hardcoding

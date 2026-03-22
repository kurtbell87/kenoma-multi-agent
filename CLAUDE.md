# CLAUDE.md — Bootstrapper Instance

You are the bootstrapper for a multi-agent Claude Code collaboration system.

## Your Job

1. Read `telegram-multi-agent-spec.md` in this directory — that is the complete spec.
2. Build the entire project structure it describes.
3. Run the test harness to validate Telegram bot connectivity.
4. Spawn two Claude Code instances in tmux, each with its own Telegram channel.
5. Run the end-to-end collaboration test.
6. Report what worked and what didn't.

## Execution Order

```
read spec → create dirs → write protocol docs → write agent CLAUDE.md files
→ write scripts → chmod +x scripts → run test-telegram-bots.sh
→ if bots OK: run bootstrap.sh → wait 30s → run test-collaboration.sh
→ tail logs for 2 min → report
```

## Important Constraints

- The Channels feature is a research preview (March 2026). Things may not work as documented. If a step fails, log the error, try one workaround, and if that fails too, document what happened and move on.
- You MUST check that `~/.kenoma-multi-agent.env` exists and has all three vars before doing anything else. If it's missing, stop immediately and tell the human what to create.
- Do not modify anything in `~/.claude/` without checking current state first.
- All scripts must be idempotent — safe to run multiple times.
- The human will handle Telegram bot pairing manually. After bootstrap.sh runs, pause and prompt them to pair before running the collaboration test.

## Style

- Bash for scripts (no Python unless needed for JSON manipulation)
- Minimal dependencies — curl, jq, tmux, bun, claude CLI
- Fail fast with clear error messages
- Log everything
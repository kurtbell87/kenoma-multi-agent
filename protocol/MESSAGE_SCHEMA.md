# Communication — Kenoma Protocol v3

This is a research lab's internal Discord channel. Communicate like professionals on Slack — natural language, @mentions for routing, concise messages.

## How to Talk

**Use @mentions to address people.** Start your message with who it's for:

```
@pi Here are the benchmark results for linear probing at load factor 0.7. Written up at shared/results/lp-0.7-bench.md
```

```
@engineer Can you add TLB miss counters to the benchmark harness?
```

```
@senior-researcher @theorist The cache-line analysis is ready for review — see shared/experiments/cache-analysis.md
```

**Broadcast to everyone** by starting with `@all`:
```
@all Heads up — the benchmark harness API changed. New usage is in shared/tools/README.md
```

## Reactions

Use the `react` tool instead of sending messages for acknowledgments. This costs zero context for everyone else.

| Reaction | Meaning |
|----------|---------|
| 👀 | "Seen it, looking into it" |
| ✅ | "Done" / "Completed" |
| 🚧 | "Working on it" |
| ❌ | "Blocked" or "Failed" |
| ❓ | "I have a question" (then send the question) |

React to the message that assigned you work. Only send a chat message when you have something substantive — a result, a question, or a blocker.

## What NOT to Do

- No JSON protocol messages. Write like a human.
- No sequence numbers, timestamps, or protocol headers.
- No "acknowledged, starting work" messages — react with 👀 instead.
- No wrapping messages in code fences (unless sharing actual code).

## Message Guidelines

- **Be concise.** Say what you need to say, reference file paths for details.
- **Don't paste file contents into chat.** Write to `shared/` and reference the path.
- **Ask questions directly.** `@theorist what's the expected probe length at load factor 0.9?` — not a JSON question object.
- **Report results naturally.** `@pi Done — L1 miss rates plateau at 0.75 load factor, full writeup at shared/results/l1-plateau.md`

## When the Department Head (Human) Speaks

Human messages are plain text without @mentions. Only PI responds to the human. Everyone else ignores human messages completely.

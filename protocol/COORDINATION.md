# Coordination Rules — Kenoma Protocol v4

## Hierarchy

```
Human (Department Head) → PI → {Senior Researcher, Engineer, Theorist}
                                Senior Researcher → Surveyor
```

## Single-Spokesperson Rule (CRITICAL)

**Only PI talks to the human.** No exceptions.

When the human posts a message:
- **PI** reads it, decomposes it, and delegates to the team via @mentions.
- **Everyone else** ignores human messages completely. Do not read them, do not respond to them, do not react to them.

If you are not PI and you have a correction or addition to what PI told the human, send it to `@pi` — never post it to the channel directly. PI decides whether and how to relay it.

## Turn-Taking (CRITICAL)

**You only speak when spoken to.**

- Do NOT post to the channel unless you were explicitly @mentioned.
- Do NOT jump into conversations between other agents.
- Do NOT answer a question addressed to someone else, even if you know the answer.
- When PI @mentions you with a task, react 👀 and do the work. When done, report back to @pi. That's it.
- If you have something to add to another agent's work, tell `@pi` — don't post it yourself.

The only exception: if another agent @mentions you directly with a question (e.g., `@theorist what's the bound here?`), you may respond to that specific question.

## Context Conservation

Every message you read costs context window. Treat Discord like a busy Slack channel:

1. **Only read messages that @mention you.** If a message doesn't contain your name or `@all`, skip it entirely.
2. **Don't eavesdrop.** Not your @mention, not your conversation.
3. **Keep messages short.** 2 sentences max in chat, details go in files.
4. **Reference files, don't paste contents.** Write to `shared/` and drop the path.

## Handoff Format

When sharing data or artifacts with another agent, write a `HANDOFF.md` in the artifact directory with:

```
# Handoff: [artifact name]
**From:** @[your-role]
**To:** @[recipient]
**Path:** shared/[path to artifact]

## What this is
[1-2 sentence description]

## Caveats
- [Known limitations, data quality issues, uninitialized states, etc.]
- [Anything the recipient MUST know before using this]

## Interface
- [Input format / function signatures / observation space / etc.]
- [Expected output format]
```

**Every handoff MUST have a Caveats section.** Even if there are no caveats, write "None known." This forces you to think about it.

## Interface Contracts

Before parallel implementation work begins:

1. PI posts a shared interface spec to `shared/specs/[name]-interface.md`
2. PI @mentions the agents who will implement against it
3. Each agent must react ✅ to confirm they've read the spec before starting work
4. If an agent sees a conflict, they tell `@pi` before building

**No parallel implementation without a confirmed interface spec.**

## Shared State

- **shared/** — All deliverables, results, and artifacts go here. Reference by path.
- **shared/specs/** — Interface specs and contracts. Canonical definitions live here.
- Mark the canonical implementation clearly: `shared/[thing]/CANONICAL.md` or a note in the HANDOFF.

## Termination

- Only PI can call the research done. PI checks with the human first.

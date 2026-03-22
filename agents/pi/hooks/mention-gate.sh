#!/usr/bin/env bash
# mention-gate.sh — Blocks Discord replies that use plain-text agent names
# instead of proper Discord <@ID> mentions. Without <@ID>, requireMention
# filtering means nobody receives the message.
set -euo pipefail

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Extract the message text
MSG="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print(d.get('text', '') or d.get('content', '') or d.get('message', ''))
except: pass
" "$TOOL_INPUT" 2>/dev/null || true)"

if [[ -z "$MSG" ]]; then
  exit 0
fi

# Known agent plain-text names that should be <@ID> mentions instead
# Case-insensitive check for these patterns when they appear to be addressing an agent
BAD_PATTERNS=(
  '@engineer'
  '@senior-researcher'
  '@theorist'
  '@strategist'
  '@surveyor'
  '@sr'
  '@all'
  'Engineer —'
  'SR —'
  'Theorist —'
  'Strategist —'
  'Surveyor —'
  'Senior Researcher —'
)

for pattern in "${BAD_PATTERNS[@]}"; do
  if echo "$MSG" | grep -qi "$pattern"; then
    # Check if the message also contains a proper <@ID> mention
    if echo "$MSG" | grep -q '<@[0-9]\+>'; then
      # Has at least one proper mention, allow it
      exit 0
    fi
    echo "BLOCKED: You used plain-text agent names instead of Discord mentions." >&2
    echo "   Plain text like '@engineer' or 'Engineer —' does NOT notify anyone." >&2
    echo "   You MUST use Discord mention syntax. Copy-paste these:" >&2
    echo "     Senior Researcher: <@1484967775280693379>" >&2
    echo "     Surveyor:          <@1485112212489113781>" >&2
    echo "     Engineer:          <@1484968253078900928>" >&2
    echo "     Theorist:          <@1484968530142302330>" >&2
    echo "     Strategist:        <@1485066642684907540>" >&2
    echo "   Rewrite your message with proper <@ID> mentions." >&2
    exit 1
  fi
done

exit 0

#!/usr/bin/env python3
"""Apply the demo agent visibility policy to the pinned upstream web bridge."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'examples/agent-web-ui/server/bridge.ts'
source = path.read_text()
replacements = {
    '      for (const a of discovered) {':
    '      for (const a of discovered) {\n        if (!["echo", "openrouter"].includes(a.agent)) continue;',
    '  private registerAgent(agent: Agent): void {':
    '  private registerAgent(agent: Agent): void {\n    if (!["echo", "openrouter"].includes(agent.agent)) return;',
}
for old, new in replacements.items():
    if new in source:
        continue
    if source.count(old) != 1:
        raise SystemExit(f'Upstream web bridge changed; cannot apply filter at {old}')
    source = source.replace(old, new)
path.write_text(source)

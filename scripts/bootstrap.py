#!/usr/bin/env python3
"""Generate isolated demo identities and a Helm values overlay of public JWTs."""
import base64
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.umask(0o077)
state = root / '.state'
state.mkdir(exist_ok=True)

def nsc(*args):
    return subprocess.check_output([str(root/'scripts/nsc'), *args], text=True).strip()

def nsc_exists(*args):
    return subprocess.run(
        [str(root/'scripts/nsc'), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0

def claims(token):
    body = token.split('.')[1]
    return json.loads(base64.urlsafe_b64decode(body + '=' * (-len(body) % 4)))

if not (state/'initialized').exists():
    if (state/'nsc').exists():
        raise SystemExit('Partial identity setup exists. Inspect .state/nsc before retrying; keys are not overwritten.')
    nsc('add', 'operator', '--generate-signing-key', '--sys', '--name', 'DEMO')
    nsc('edit', 'operator', '--require-signing-keys', '--account-jwt-server-url', 'nats://localhost:15222')
    (state/'initialized').touch()

# Existing administration stores are reused; only active identities are managed.
if not nsc_exists('describe', 'account', '--name', 'AGENTS'):
    nsc('add', 'account', 'AGENTS')
    nsc('edit', 'account', 'AGENTS', '--sk', 'generate')
for user in ['web', 'echo', 'openrouter']:
    if not nsc_exists('describe', 'user', '--account', 'AGENTS', '--name', user):
        nsc('add', 'user', '--account', 'AGENTS', '--name', user)

# The browser can discover services and call only the two supported agents.
nsc(
    'edit', 'user', '--account', 'AGENTS', '--name', 'web',
    '--allow-pub', '$SRV.>,agents.prompt.echo.demo.main,agents.prompt.openrouter.demo.main,agents.status.echo.demo.main,agents.status.openrouter.demo.main,_INBOX.>',
    '--allow-sub', '_INBOX.>,agents.hb.>',
)
for agent in ['echo', 'openrouter']:
    nsc(
        'edit', 'user', '--account', 'AGENTS', '--name', agent,
        '--allow-pub', f'agents.hb.{agent}.demo.main',
        '--allow-sub', f'$SRV.>,agents.prompt.{agent}.demo.main,agents.status.{agent}.demo.main',
        '--allow-pub-response=1000', '--response-ttl', '10m',
    )

operator = nsc('describe', 'operator', '--raw')
accounts = {
    name: nsc('describe', 'account', '--name', name, '--raw')
    for name in ['SYS', 'AGENTS']
}
config = {'operator': operator, 'system_account': claims(accounts['SYS'])['sub'],
          'resolver_preload': {claims(token)['sub']: token for token in accounts.values()}}
(state/'auth-values.json').write_text(json.dumps({'nats': {'config': {'merge': config}}}, indent=2)+'\n')
credentials = [
    ('AGENTS', 'web', 'agent-web.creds'),
    ('AGENTS', 'echo', 'agent-echo.creds'),
    ('AGENTS', 'openrouter', 'agent-openrouter.creds'),
]
for account, user, filename in credentials:
    nsc('generate', 'creds', '--account', account, '--name', user, '--output-file', str(state/filename))
print('Demo identities ready. Private keys remain in .state; Helm receives public JWTs only.')

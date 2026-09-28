# Web agent UI, Echo, and OpenRouter

```text
Browser → Web UI → authenticated NATS → Echo (in Kubernetes)
                                    → OpenRouter agent → hosted model API
```

The web server, NATS, and Echo run in a local kind cluster. The OpenRouter agent
runs on the host. The browser lists only Echo and OpenRouter. This local demo
uses localhost port-forwards without TLS; it is not a public hosting setup.

## Requirements

Use macOS, Linux, or Windows with WSL2. On Windows, run the commands inside a
WSL2 Linux distribution with Docker Desktop integration enabled. Native
PowerShell launchers are not included. Linux and WSL2 still need end-to-end validation.

Install Git, Docker, kind, kubectl, Helm, Python 3, Node.js/npm, and NSC for your
system and CPU architecture. NSC can be on PATH, at `.tools/nsc`, or selected
with `NSC_BIN`. Agent preparation installs a local Bun runtime automatically.
No AI command-line application is required.

Run all commands below from `nats/agents-demo`:

```bash
./scripts/check-platform.sh
```

## First-time installation

Start Docker, then create the cluster and install the services:

```bash
kind create cluster --name nats-agents-demo --kubeconfig "$PWD/kubeconfig"
./scripts/install.sh
./scripts/prepare-openrouter-agent.sh
```

Skip cluster creation when the cluster already exists. Installation can be
rerun to apply configuration changes. It generates identities, builds pinned
upstream Web UI and Echo images, loads them into kind, and installs the chart.
NATS uses the bundled Helm chart version 2.15.0 with JetStream disabled.

### Existing installations after the project rename

Renaming the source folder does not rename an existing kind cluster or Helm
release. The startup port-forwards continue to use the cluster recorded in the
local `kubeconfig`; the installation and image-loading scripts now target
`nats-agents-demo`.

To switch to the new cluster name, stop the three startup terminals, then run
these commands from `nats/agents-demo`:

```bash
kind create cluster --name nats-agents-demo --kubeconfig "$PWD/kubeconfig"
./scripts/install.sh
```

Run this only if the newly named cluster does not already exist. The local
`.state` directory and saved API key move with the source folder and are reused.
Restart the three startup scripts afterward. The previous cluster remains
intact; list clusters with `kind get clusters` and remove it separately when
you no longer need it.

### Save the OpenRouter key

Create a key in [OpenRouter settings](https://openrouter.ai/settings/keys).
If you have not already saved one, run the following in Bash without echoing
the key (start `bash` first if your terminal uses another shell):

```bash
mkdir -p .state
chmod 700 .state
read -r -s -p "OpenRouter API key: " OPENROUTER_API_KEY; echo
(umask 077; printf '%s\n' "$OPENROUTER_API_KEY" > .state/openrouter-api-key)
unset OPENROUTER_API_KEY
```

The launcher reads `.state/openrouter-api-key` automatically. An exported
`OPENROUTER_API_KEY` takes precedence. The key is not included in container
images or sent to the browser.

## Startup after installation

Start Docker and ensure the existing `nats-agents-demo` kind cluster is running.
You do not need to rerun installation for normal startup. NATS, Echo, and the
UI server run in the cluster; the scripts below start the host OpenRouter agent
and expose the services locally.

Keep these three terminals open, each in `nats/agents-demo` (run
`cd nats/agents-demo` from the project root in each terminal):

```bash
# Terminal 1: connect the host agent to NATS
./scripts/port-forward
```

Wait for Terminal 1 to print `Forwarding from ...` before starting Terminal 2.

```bash
# Terminal 2: start OpenRouter with the saved key
./scripts/start-openrouter-agent.sh
```

```bash
# Terminal 3: expose the web UI locally
./scripts/open-agent-web.sh
```

Open http://localhost:3300 and select **openrouter / demo / main** or
**echo / demo / main**. Echo answers `echo: <your prompt>` and needs no API key.
Run only one instance of each launcher. If a forwarding port is already in use,
check whether its existing terminal is still running.

Press Ctrl+C in each terminal to stop the host agent and tunnels. Kubernetes
services keep running while Docker and the cluster are running.

### Setup and startup scripts

| Script | When to use it |
| --- | --- |
| `./scripts/check-platform.sh` | Before first-time setup; checks required executables. |
| `./scripts/install.sh` | After cluster creation, or to apply deployment changes; generates identities, builds/loads images, and installs the services. |
| `./scripts/prepare-openrouter-agent.sh` | During first-time setup or after changing the OpenRouter dependencies; installs Bun and agent dependencies. |
| `./scripts/port-forward` | Each session; exposes NATS at `127.0.0.1:15222`. |
| `./scripts/start-openrouter-agent.sh` | Each session; starts the host agent and reads the saved API key. Automatically runs preparation if required files are missing. |
| `./scripts/open-agent-web.sh` | Each session; exposes the UI at `http://localhost:3300`. |

For an Echo-only connection check, run `./scripts/open-agent-web.sh` and select
Echo in the browser. The host OpenRouter agent, API key, and NATS port-forward
are only needed for OpenRouter.

## OpenRouter behavior and configuration

The default model is `openrouter/free`. Free-model availability and quotas vary.
Set `OPENROUTER_MODEL` to choose another model; paid models may incur charges.

```bash
OPENROUTER_MODEL='provider/model:free' ./scripts/start-openrouter-agent.sh
```

Replace the example model ID with one listed by OpenRouter. The agent sends only
the supplied prompt and a fixed system instruction. It is stateless and text-only,
with no filesystem, shell, browsing, or attachment tools. Answers arrive when
the model finishes, with keepalives while waiting. Requests time out after 90
seconds, cap output at 2,048 tokens, and are not automatically retried.

| Setting | Default |
| --- | --- |
| `OPENROUTER_API_KEY` | Read from `.state/openrouter-api-key` |
| `OPENROUTER_MODEL` | `openrouter/free` |
| `NATS_URL` | `nats://127.0.0.1:15222` |
| `NATS_CREDS` | `.state/agent-openrouter.creds` |
| `BUN_BIN` | `.tools/bun/node_modules/.bin/bun` |
| `NSC_BIN` | `.tools/nsc`, then `nsc` on PATH |

## Project layout

- `agents/openrouter/` — API client, NATS service, and client tests.
- `scripts/` — prerequisite check, identity generation, image build, install,
  preparation, and the three runtime launchers.
- `images/` — Web UI and Echo container recipes.
- `templates/`, `values.yaml`, `Chart.yaml`, `charts/` — Kubernetes deployment.
- `.state/` — private credentials, saved API key, administration store, and caches.
- `.tools/` — local executables.

The build fetches only the needed upstream Web UI and Echo source directories.
`scripts/patch-agent-web.py` restricts manual discovery and automatic discovery
to the supported agents. JWT identities separate the browser, Echo, and
OpenRouter. The browser's NATS credentials stay on its server.

For another machine, copy the source without `.state`, `.tools`, `node_modules`,
or `kubeconfig`, then perform first-time installation. Existing administration
stores are reused without deleting historical identities; bootstrap manages only
the current Web UI, Echo, and OpenRouter identities.

## Development notes

The maintained OpenRouter code is in `agents/openrouter/`. After editing it,
restart `scripts/start-openrouter-agent.sh` to load the changes.

The UI and Echo are fetched at commits pinned in `scripts/build-agent-images.sh`.
Their sources under `.state/sources/` are disposable build inputs. Keep durable
UI customizations in `scripts/patch-agent-web.py` or the container recipe.
The UI image replaces the upstream SDK's `file:` dependency with the published
`^0.5.2` package, installs dependencies, and runs the Vite build inside Docker.

The image script reuses an image when its configured tag already exists.
Rerunning installation alone does not rebuild that image. When changing an
image recipe or UI patch, update its tag in both `scripts/build-agent-images.sh`
and `values.yaml`, then rerun `scripts/install.sh`.

### UI TypeScript warnings in the editor

The cached UI checkout has no locally installed dependencies. Its
`tsconfig.json` references `bun` and `vite/client`, so the editor can report
missing type definitions. Those dependencies are installed inside the UI
container build. This warning alone does not indicate a runtime failure.
The image build runs `vite build`, not a separate TypeScript check.

Do not run `bun install` in the sparse UI checkout expecting a complete upstream
development environment: its original package file references an SDK directory
that is not fetched. Full SDK development and release instructions are outside
this demo's scope; upstream documentation in the cache may describe unavailable
packages. A fresh upstream checkout may restore those documentation files.

## Validation

After installation and agent preparation, run:

```bash
.tools/bun/node_modules/.bin/bun test agents/openrouter/client.test.ts
helm lint . -f .state/auth-values.json
kubectl --kubeconfig ./kubeconfig -n nats-demo get pods,pvc
```

## Delete the local cluster

```bash
kind delete cluster --name nats-agents-demo
```

This deletes the cluster and its volumes. Local keys and caches in `.state`
remain available for a later installation.

References:

- [OpenRouter quickstart](https://openrouter.ai/docs/quickstart)
- [OpenRouter free model router](https://openrouter.ai/openrouter/free)
- [Synadia agents](https://github.com/synadia-ai/synadia-agents)
- [Synadia agents labs](https://github.com/synadia-ai/synadia-agents-labs)

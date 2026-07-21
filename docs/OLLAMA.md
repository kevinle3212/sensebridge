# Local AI — Ollama + Continue.dev

Optional, free, on-device coding assistance that complements Claude rather
than replacing it. Nothing here touches the app's own on-device-by-default
architecture (`docs/PRIVACY.md`) — this is developer tooling, not product
code, but it follows the same spirit: your prompts and code never leave your
LAN.

## Topology

Two machines, one Ollama server:

- **iMac (8 GB RAM)** — hosts Ollama. RAM is the binding constraint, so
  models here stay small (≤ ~2.5 GB) to leave headroom for macOS and the
  editor.
- **MacBook (dev machine)** — runs the Continue.dev extension and talks to
  the iMac's Ollama server over the LAN, with a `localhost` fallback for when
  you're working directly on the iMac or the LAN host is unreachable.

`~/.continue/config.yaml` (global, per machine — never committed) is where
this is wired up. `.continue/config.template.yaml` in this repo is an
**example only**; Continue never reads it. `.continue/rules/` holds the
project-specific instructions that layer on top, regardless of which model
backs a given role.

## Install

```sh
brew install ollama
```

Start the server (foreground, for testing):

```sh
ollama serve
```

For the iMac (the always-on host), run it as a background service instead of
a foreground process — `brew services start ollama` registers a LaunchAgent
that starts Ollama on login and restarts it if it crashes.

## Models

| Role | Model | Size | Roles in config |
| --- | --- | --- | --- |
| Chat / edit / apply / subagent | `qwen3:4b` | ~2.5 GB | `chat`, `edit`, `apply`, `subagent` |
| Autocomplete (FIM) | `qwen2.5-coder:1.5b-base` | ~986 MB | `autocomplete` |

```sh
ollama pull qwen3:4b
ollama pull qwen2.5-coder:1.5b-base
```

Both models were chosen for the 8 GB iMac: together they use well under
4 GB resident, leaving room for the OS and Ollama's own overhead. `qwen3:4b`
supports tool use, which Continue's `apply` and `subagent` roles need.
`qwen2.5-coder:1.5b-base` is a *base* (non-instruct) checkpoint — the
correct choice for fill-in-the-middle autocomplete, which wants raw
completion behavior, not chat formatting.

### Optional upgrade path (MacBook only, more RAM available)

If the MacBook runs Ollama locally instead of relying on the iMac (e.g.
working offline), and has enough RAM to spare (16 GB+), larger models give
noticeably better edit/autocomplete quality:

```sh
ollama pull qwen2.5-coder:7b   # better edit/chat quality
ollama pull codestral:22b      # highest-quality FIM autocomplete, if RAM allows
```

Add these as additional `models:` entries in `~/.continue/config.yaml` with
`apiBase: http://localhost:11434`, rather than replacing the iMac-hosted
entries — Continue picks the first matching model per role, so order
matters if you keep both.

## Setup

```sh
cp .continue/config.template.yaml ~/.continue/config.yaml
chmod 600 ~/.continue/config.yaml
```

Edit `apiBase` in the copied file:

- Working on the iMac itself, or no LAN host available: leave it as
  `http://localhost:11434`.
- Working on the MacBook, iMac reachable on the LAN: point `apiBase` at the
  iMac's LAN IP (`http://<imac-lan-ip>:11434`). Keep a second `localhost`
  entry for the same role as a fallback — Continue falls through in order if
  the first is unreachable.

Verify the server has the expected models before opening the editor:

```sh
ollama list
```

## CLI usage

```sh
ollama run qwen3:4b "explain this function"   # one-off prompt, interactive
ollama list                                    # installed models
ollama ps                                      # currently loaded models + VRAM/RAM use
ollama rm <model>                              # free disk space
```

## VS Code usage

1. Install the **Continue** extension.
2. `Cmd+L` — chat with the configured `chat` model, project rules from
   `.continue/rules/` applied automatically.
3. `Cmd+I` — inline edit on a selection, using the `edit` role.
4. Autocomplete fires inline as you type, using the `autocomplete` role — no
   keybinding needed.
5. Continue's agent mode (tool-calling, multi-step) uses the `subagent` role.

## Recommended workflows

Local models are good for fast, mechanical, low-ambiguity work where round
trip latency and zero cost matter more than reasoning depth:

- Autocomplete while typing.
- Boilerplate (getters/setters, test scaffolding, repetitive config).
- Quick explanations of an existing function.
- Working offline or away from the LAN (MacBook local Ollama).

## When to prefer local vs. Claude

| Prefer local (Ollama) | Prefer Claude |
| --- | --- |
| Autocomplete, boilerplate, mechanical edits | Architecture, security review, cross-file refactors |
| No network / offline | Anything needing this repo's skills, agents, or MCP tools (none of those are visible to Continue) |
| Zero cost, unlimited iteration | Ambiguous requirements needing judgment |
| Small, single-file context | Large context, multi-file reasoning, safety-framing-sensitive output |

If a local model's answer is uncertain or the task touches the three
SenseBridge doctrines (`AGENTS.md`), escalate to Claude rather than trusting
a small model's judgment on safety-framing, privacy, or accessibility calls.

## Security posture

- `apiBase` should only ever point at a LAN address, never a
  publicly-routable one — Ollama's API has no built-in auth.
- `~/.continue/config.yaml` is `chmod 600` even though it currently holds no
  secrets, as a default-safe habit for a file that could later gain an API
  key for a hosted role.
- `~/.continue/.continuerc.json` sets `disableIndexing: true` — Continue's
  built-in codebase indexer is redundant with Serena's semantic index
  already used in this repo, and skipping it saves RAM on the 8 GB iMac.
- No prompt, completion, or code leaves the local network — this is the
  same on-device-by-default posture the app itself follows, applied to
  tooling.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).

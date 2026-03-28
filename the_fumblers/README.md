# 🌌 heimdall

**Distributed Node Orchestration & Health Monitoring Platform**

heimdall is a lightweight Python platform that continuously polls registered services for their health, tracks failure counts, and delivers alerts through Discord, Telegram, or generic webhooks — all exposed via a clean REST API.

---

## Features

- **Async heartbeat polling** — orchestrator checks every registered node's `/heartbeat` endpoint on a loop using `asyncio` + `httpx`
- **Resilience thresholds** — nodes aren't marked `OFFLINE` on the first failure; a configurable `FAIL_THRESHOLD` prevents false positives
- **Multi-channel alerts** — integrations for Discord bots, Telegram bots, and generic webhooks
- **Live status API** — `GET /nodes` returns real-time status of all registered nodes
- **Pluggable nodes** — any FastAPI service that exposes `/heartbeat` becomes a Stellaris node instantly
- **Reproducible dev environment** — Nix flake included for zero-dependency-conflict setup

---

## Architecture

```
┌─────────────┐     heartbeat poll     ┌─────────────────────────────┐
│   Node A    │ ──────────────────────▶│                             │
├─────────────┤                        │      Orchestrator           │──▶ GET /nodes  (REST)
│   Node B    │ ──────────────────────▶│   FastAPI + asyncio         │──▶ Discord Bot
├─────────────┤                        │   fail_count tracking       │──▶ Telegram Bot
│   Node C    │ ──────────────────────▶│                             │──▶ Webhook
└─────────────┘                        └─────────────────────────────┘
```

Each node exposes a `/heartbeat` endpoint. The orchestrator polls all nodes, increments `fail_count` on failures, and flips status to `OFFLINE` once the threshold is crossed.

---

## Project Structure

```
stellaris/
├── orchestrator.py        # Core: async polling loop, node state, REST API
├── node.py                # Lightweight FastAPI heartbeat microservice
├── api.py                 # API layer / shared app setup
├── test.py                # General tests
├── test_orchaestrator.py  # Orchestrator-specific tests (monkeypatched)
├── flake.nix              # Nix development environment
├── flake.lock             # Locked Nix dependencies
└── .envrc                 # direnv hook: `use flake`
```

---

## Getting Started

### Prerequisites

- Python 3.10+
- [Nix](https://nixos.org/) (recommended) **or** install dependencies manually

### With Nix (recommended)

```bash
# Enter the dev shell — all dependencies are loaded automatically
direnv allow    # if you use direnv
# or
nix develop
```

### Without Nix

```bash
pip install fastapi uvicorn httpx pytest
```

### Run the Node

```bash
uvicorn node:app --port 8001
```

The node exposes:

```
GET /heartbeat  →  { "status": "alive", "time": "2025-03-28T10:00:00Z" }
```

### Run the Orchestrator

```bash
uvicorn orchestrator:app --port 8000
```

The orchestrator exposes:

```
GET /nodes  →  { "node1": { "url": "...", "status": "ONLINE", "fail_count": 0, "last_seen": "..." } }
```

---

## Configuration

Edit the node registry inside `orchestrator.py` to add your services:

```python
NODES = {
    "node1": {
        "url": "http://localhost:8001",
        "status": "UNKNOWN",
        "fail_count": 0,
        "last_seen": None,
    }
}

FAIL_THRESHOLD = 3   # failures before a node is marked OFFLINE
```

---

## Node Status Reference

| Status    | Meaning                                              |
|-----------|------------------------------------------------------|
| `UNKNOWN` | Node registered but not yet polled                   |
| `ONLINE`  | Last heartbeat succeeded; `fail_count` reset to 0    |
| `OFFLINE` | `fail_count` reached `FAIL_THRESHOLD`                |

---

## Running Tests

```bash
pytest test.py test_orchaestrator.py -v
```

Tests use `monkeypatch` to inject fake HTTP clients — no live services required.

### What's tested

- Node `/heartbeat` returns `{ status, time }` with a UTC timestamp
- Orchestrator marks node `ONLINE` and resets `fail_count` on success
- Orchestrator marks node `OFFLINE` after `FAIL_THRESHOLD` consecutive failures
- `fail_count` increments correctly on single failure (status stays `UNKNOWN`)
- Status transitions: `UNKNOWN → ONLINE → OFFLINE`
- `GET /nodes` endpoint returns the full registry

---

## Notification Integrations

Each integration lives in its own branch and can be merged independently.

| Channel       | Branch                 | Status      |
|---------------|------------------------|-------------|
| Discord Bot   | `ft.connect_discord`   | ✅ Complete |
| Telegram Bot  | `ft.connect_telegram`  | ✅ Complete |
| Webhook       | `ft.addwebhook`        | ✅ Complete |
| Node Auto-reg | `ft.add_node_service`  | 🚧 In progress |

---

## Tech Stack

| Layer         | Technology          |
|---------------|---------------------|
| Web framework | FastAPI             |
| Async HTTP    | httpx               |
| Testing       | pytest              |
| Runtime       | Python asyncio      |
| Dev env       | Nix flakes + direnv |

---

## Contributing

1. Fork the repo and create a branch from `master`
2. Follow the `ft.<feature>` naming convention for feature branches
3. Add or update tests for any changed behaviour
4. Open a pull request with a clear description

---

## License

MIT — see `LICENSE` for details.

<div align="center">
  <h1>🪄 DeepClaude + Headroom / Gate</h1>
  <p><strong>Automated setup of Headroom AI proxy with DeepClaude for Claude Code via DeepSeek API</strong></p>
  <p>
    <img src="https://img.shields.io/badge/headroom-0.27.2.0-blue" alt="Headroom">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
    <img src="https://img.shields.io/badge/platform-linux-lightgrey" alt="Linux">
  </p>
  <br>
</div>

Run **Claude Code** using the **DeepSeek API** (drastically cheaper) with the **Headroom proxy** (context compression, cache, code-aware, MCP).

> 🔐 **Optional:** pair with [headroomgate](https://github.com/estrazulas/headroomgate) — a hardened fork that adds multi-user API key auth, encrypted provider keys, per-user rate limiting, semantic audit trail, and usage history on top of all upstream compression features. See [how to install](#-headroomgate--auth--audit-recommended-for-teams).

> 💰 DeepSeek V4 Pro: ~$0.44/M input vs Anthropic: ~$3.00/M input  
> 💰 DeepSeek V4 Pro: ~$0.87/M output vs Anthropic: ~$15.00/M output  
> 📉 Headroom saves an additional 5–16% via context compression + output shaping  
> 🎥 [How Headroom saves tokens](https://youtu.be/UOWSHg18cL0) — by the creator [@chopratejas](https://github.com/chopratejas)  
> 📊 [Why use DeepClaude with Headroom](benchmark/) — by [@estrazulas](https://github.com/estrazulas)  
>  
> | Scenario | Direct | Proxy | Saved |  
> |---|---|---|---|  
> | Building a CLI app from scratch | $0.0126 | $0.0116 | **-8.2%** |  
> | Debugging production incidents | $0.0126 | $0.0106 | **-16.2%** |

---

### Original projects

This installer is a wrapper that configures and automates two awesome open-source projects:

| Project | Author | Repo |
|---------|--------|------|
| **DeepClaude** | [@aattaran](https://github.com/aattaran) | [github.com/aattaran/deepclaude](https://github.com/aattaran/deepclaude) |
| **Headroom** | [@chopratejas](https://github.com/chopratejas) | [github.com/chopratejas/headroom](https://github.com/chopratejas/headroom) |

DeepClaude provides the Claude Code ↔ DeepSeek bridge. Headroom adds context compression, caching, code-aware optimization, and MCP support on top.

---

## 📦 What it installs

| Component | Description |
|-----------|-------------|
| **Headroom CLI** | Compression proxy with `[proxy,code,mcp]` (light) or `[all]` (complete) extras |
| **Headroom systemd service** | Auto-start on Linux boot |
| **deepclaude** | Terminal command — Claude Code via DeepSeek |
| **deepclaudehr** | Terminal command — Claude Code via Headroom proxy (with optional auth) |
| **`/headroom_usage`** | Claude Code slash command — proxy savings dashboard |
| **DEEPSEEK_API_KEY** | Auto-configured in shell (.zshrc/.bashrc) |
| **`~/.config/headroom/env`** | Auth config (headroomgate fork only, created as template) |

---

## 📋 Prerequisites

> 🐧 **Linux only.** The installer and systemd service assume a Linux distribution with `systemd --user` support (Ubuntu ≥ 20.04, Debian ≥ 11, Fedora ≥ 35, Arch, etc.).

| Requirement | Why | Install |
|-------------|-----|---------|
| **Claude Code** | Slash commands, settings.json | `npm install -g @anthropic-ai/claude-code` |
| **Python 3** | JSON mangling, health check parsing | `sudo apt install python3` |
| **curl** | Custom `.whl` download, health check | `sudo apt install curl` |
| **git** | Clone this repo | `sudo apt install git` |
| **sudo** | Install deepclaude to `/usr/local/bin`, apt for pipx | Included in most distros |
| **DeepSeek API Key** | Proxy ↔ DeepSeek communication | [platform.deepseek.com](https://platform.deepseek.com) |

> ℹ️ `pipx` is installed automatically by the script if missing (`sudo apt install pipx`).  
> ℹ️ `jq` is not required for installation but useful for querying `/stats` (see Usage).

---

## 🚀 Installation

```bash
git clone https://github.com/estrazulas/deepclaude_with_headroom.git
cd deepclaude_with_headroom
bash install.sh   # interactive launcher — choose the mode
```

### Installation modes

```
install.sh (launcher)
│
├─ [1] setup_local_hr_only.sh
│   └─ Proxy local (original PyPI)
│       ├── pipx install headroom-ai[proxy,code,mcp]
│       ├── systemd service (no auth)
│       ├── DEEPSEEK_API_KEY → ~/.zshrc
│       ├── deepclaude + deepclaudehr
│       └── /headroom_usage
│
├─ [2] setup_local_hr_gate.sh
│   └─ Proxy local (headroomgate fork)
│       ├── pipx install headroom-ai[proxy,code,mcp,auth]
│       ├── pipx inject headroom-auth (plugin)
│       ├── ~/.config/headroom/env (Neo4j + Qdrant)
│       ├── systemd service (WITH auth + log-messages)
│       ├── deepclaude + deepclaudehr
│       ├── /headroom_usage
│       └── 📋 Bootstrap instructions (admin creates keys)
│
└─ [3] setup_new_dev_hr_gate.sh
    └─ Dev client (REMOTE proxy)
        ├── ~/.config/headroom/env (PROXY_URL + API_KEY)
        ├── deepclaude + deepclaudehr
        ├── /headroom_usage
        └── ❌ no pipx, systemd, Neo4j, Qdrant
```

| Mode | Proxy | Auth | Neo4j | Ideal for |
|:----:|:-----:|:----:|:-----:|------------|
| 1 | localhost | ❌ | ❌ | Personal use, compression |
| 2 | localhost | ✅ | ✅ | Admin managing the team |
| 3 | **remote** | ✅ | ❌ | Dev using admin's proxy |

### 🔐 Headroomgate — Auth + Audit (recommended for teams)

The [headroomgate](https://github.com/estrazulas/headroomgate) fork adds multi-user authentication, per-user rate limiting, request audit trail, semantic search, and encrypted provider key storage — on top of all upstream compression features.

**Via installer (recommended):**
```bash
bash install.sh \
  --headroom-release "https://github.com/estrazulas/headroomgate/releases/download/v0.27.2.0/headroom_ai-0.27.2.0-cp310-abi3-manylinux_2_35_x86_64.whl" \
  --headroom-sha256 "dfc532ab67ec85b1c912467d57c9dc6a664945db9d52beca26d1740742e91746" \
  --headroom-auth-sha256 "e4d89de534df47efe56b35611816978e7e43146448ec5be7268f59cf5d03547f"
```

The auth plugin wheel is auto-derived from the main URL (`headroom_ai` → `headroom_auth`). Use `--headroom-auth-release` / `--headroom-auth-sha256` for explicit control.

**Manual install (2 wheels):**
```bash
pipx install --force \
  "https://github.com/estrazulas/headroomgate/releases/download/v0.27.2.0/headroom_ai-0.27.2.0-cp310-abi3-manylinux_2_35_x86_64.whl[proxy,code,mcp,auth]"
pipx inject headroom-ai \
  "https://github.com/estrazulas/headroomgate/releases/download/v0.27.2.0/headroom_auth-0.1.0-py3-none-any.whl"
```

After install, follow the **bootstrap instructions** printed by the installer to create your admin user, API key, and provider keys.

### 🛡️ Custom release (generic)

Any custom `.whl` works with `--headroom-release`. For integrity, pass `--headroom-sha256`.

```bash
bash install.sh \
  --headroom-release "https://github.com/<you>/<repo>/releases/download/vX.Y.Z/headroom_ai-X.Y.Z-....whl" \
  --headroom-sha256 "abc123..."
```

| Flag | Purpose |
|------|---------|
| `--headroom-release <url>` | Use your own `.whl` instead of the official PyPI package |
| `--headroom-sha256 <hash>` | Verify main wheel integrity before installing |
| `--headroom-auth-release <url>` | Auth plugin `.whl` (headroomgate, usually auto-derived) |
| `--headroom-auth-sha256 <hash>` | Verify auth plugin integrity |
| `--full` | Install all extras (`[all]`) without prompting |
| `--dry-run` | Simulate installation — print what would happen |

> ⚠️ Without `--headroom-sha256` the installer skips integrity verification.

### ⚡ Default — Light headroom + DeepClaude

```bash
bash install.sh
```

Installs `headroom-ai[proxy,code,mcp]` (~100 MB), prompting before each step:
- Headroom CLI (via pipx)
- Headroom proxy as a systemd service (auto-start)
- `deepclaude` and `deepclaudehr` terminal commands
- `/headroom_usage` slash command
- `DEEPSEEK_API_KEY` in your shell config
- Health check at the end

### 🔥 Full (all headroom extras)

```bash
bash install.sh --full
```

Installs `headroom-ai[all]` (~2 GB) without prompting — includes vector memory, image support, ML, etc. Plus everything from the default install.

---

## 🎮 Usage

### Claude Code slash commands

```
/headroom_usage          → proxy savings dashboard
/headroom_usage -v       → full /stats JSON
/headroom_usage -j       → raw JSON
/headroom_usage -p       → Prometheus metrics
```

### Terminal commands

```bash
deepclaude           → Claude Code via DeepSeek (cheaper)
deepclaudehr         → deepclaude + Headroom proxy (cheaper + compression on)
deepclaude --status  → key and backend status
deepclaude --cost    → pricing comparison
deepclaude -b or     → use OpenRouter backend
```

### Headroom proxy

```bash
systemctl --user status headroom.service          # Status
journalctl --user -u headroom.service -f          # Live logs
curl localhost:8787/health | python3 -m json.tool # Health check
curl localhost:8787/stats | jq '.summary.compression'  # Savings
```

---

## 🏗️ Architecture

```
You (terminal)
       │
       ├── deepclaude ──────────────────────────────────────► DeepSeek API
       │                                                      (direct, no proxy)
       │
       ├── deepclaudehr ───► Headroom Proxy (:8787) ────────► DeepSeek API
       │   (standard)        │                                (compression)
       │                     ├── context compression
       │                     ├── smart caching
       │                     ├── code-aware (AST)
       │                     └── MCP support
       │
       └── deepclaudehr ───► Headroom Proxy (:8787) ────────► DeepSeek API
           (with headroomgate) │                              (compression + auth gateway)
                               ├── everything above +
                               ├── 🔐 API key authentication
                               ├── 👥 user/team management
                               ├── 🔑 encrypted provider keys
                               ├── 📋 audit trail (Neo4j)
                               ├── 🔍 semantic search (Qdrant)
                               ├── ⏱️ per-user rate limiting
                               └── 📊 usage history
```

---

## ⚙️ Environment variables

| Variable | Value | Required |
|----------|-------|:--------:|
| `DEEPSEEK_API_KEY` | `sk-...` | ✅ |
| `OPENROUTER_API_KEY` | `sk-...` | For OpenRouter |
| `FIREWORKS_API_KEY` | `...` | For Fireworks |
| `HEADROOM_API_KEY` | `hr_...` | headroomgate auth — sourced by `deepclaudehr` from `~/.config/headroom/env` |
| `HEADROOM_ENCRYPTION_KEY` | `...` | headroomgate encryption — stored in `~/.config/headroom/env` |

**Headroomgate config file** (`~/.config/headroom/env`):

The installer creates this template on fork install. `deepclaudehr` sources it at runtime. After running the auth bootstrap (`headroom auth init-db`, `create-user`, `create-key`, `generate-key`), the placeholders are replaced with real keys:

```bash
HEADROOM_API_KEY="hr_your_generated_key"
HEADROOM_ENCRYPTION_KEY="your_generated_encryption_key"
```

No provider keys are stored here — they live encrypted in Neo4j, decrypted on-the-fly by the auth middleware.

Set automatically by deepclaude:

| Variable | Value |
|----------|-------|
| `ANTHROPIC_BASE_URL` | `https://api.deepseek.com/anthropic` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `deepseek-v4-pro` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `deepseek-v4-pro` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `deepseek-v4-flash` |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `deepseek-v4-flash` |

---

## 🩺 Troubleshooting

### Headroom won't start

```bash
journalctl --user -u headroom.service -n 50 --no-pager
~/.local/bin/headroom proxy --memory --learn --code-aware \
  --anthropic-api-url https://api.deepseek.com/anthropic
ss -tlnp | grep 8787  # check port
```

### deepclaudehr can't connect to proxy

```bash
systemctl --user status headroom.service
curl -s http://localhost:8787/health | python3 -m json.tool
systemctl --user start headroom.service
```

### Can't install Headroom in a virtual machine

If running inside a virtual machine (VM), the hypervisor must expose hardware virtualization features to the guest. Without this, components that depend on acceleration may fail.

```bash
# Validate — must return 2 or more
egrep -c '(vmx|svm)' /proc/cpuinfo
```

If the command returns `0`, enable **Nested VT-x/AMD-V** in your VM settings:

| Hypervisor | Setting |
|------------|---------|
| **VirtualBox** | *System → Processor →* ✅ *Enable Nested VT-x/AMD-V* |
| **VMware** | *Processors →* ✅ *Virtualize Intel VT-x/EPT or AMD-V/RVI* |
| **KVM/QEMU** | `virsh edit <vm>` → `<cpu mode='host-passthrough'/>` |
| **Proxmox** | *VM → Hardware → Processors →* Type: `host` |
| **Hyper-V** | `Set-VMProcessor -VMName <name> -ExposeVirtualizationExtensions $true` |

After enabling, reboot the VM and validate again with the command above (result ≥ 2).

### Slash commands not showing in Claude Code

```bash
ls -la ~/.claude/commands/*.md ~/.claude/commands/bin/
cat ~/.claude/settings.local.json
# Then: /reload inside Claude Code
```

---

## 📄 License

MIT

<div align="center">
  <h1>🪄 DeepClaude + Headroom</h1>
  <p><strong>Automated setup of Headroom AI proxy with DeepClaude for Claude Code via DeepSeek API</strong></p>
  <p>
    <img src="https://img.shields.io/badge/headroom-0.25.1-blue" alt="Headroom">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
    <img src="https://img.shields.io/badge/platform-linux-lightgrey" alt="Linux">
  </p>
  <br>
</div>

Run **Claude Code** using the **DeepSeek API** (drastically cheaper) with the **Headroom proxy** (context compression, cache, code-aware, MCP).

> 💰 DeepSeek V4 Pro: ~$0.44/M input vs Anthropic: ~$3.00/M input  
> 💰 DeepSeek V4 Pro: ~$0.87/M output vs Anthropic: ~$15.00/M output  
> 📉 Headroom saves an additional 5–16% via context compression

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
| **deepclaudehr** | Shorthand — deepclaude + Headroom proxy |
| **`/headroom_usage`** | Claude Code slash command — proxy savings dashboard |
| **`/mem`** | Claude Code slash command — persistent memory browser |
| **DEEPSEEK_API_KEY** | Auto-configured in shell (.zshrc/.bashrc) |

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

# Installs the official headroom‑ai from PyPI (unless --headroom-release is given)
bash install.sh
```

### Flag combinations

| Flag | Headroom | DeepClaude | Best for |
|------|----------|:----------:|:---------|
| *(none)* | ⚡ Light `[proxy,code,mcp]` *(prompts)* | ✅ | Proxy + DeepClaude |
| `--full` | 🔥 Complete `[all]` *(auto)* | ✅ | Everything |
| `--headroom-release <url>` | 🛡️ Your own `.whl` release | ✅ | Internal/audited builds |

### 🛡️ Custom release (your own fork or audited build)

If you compiled headroom from source — whether a security-hardened fork, an internal build, or a patched version — pass the `.whl` URL with `--headroom-release`. For integrity, you can also provide the expected SHA256 so the installer verifies the file before pipx installs it.

```bash
# Generic — any custom .whl
bash install.sh \
  --headroom-release "https://github.com/<you>/<repo>/releases/download/v0.25.1/headroom_ai-0.25.1-cp310-abi3-manylinux_2_35_x86_64.whl" \
  --headroom-sha256 "abc123..."
```

```bash
# Example — security‑hardened sanitizer build
bash install.sh \
  --headroom-release "https://github.com/estrazulas/headroom_sanitizer/releases/download/v0.25.1/headroom_ai-0.25.0-cp310-abi3-manylinux_2_35_x86_64.whl" \
  --headroom-sha256 "63601398d73a3bcfb56e50b6b0d251ce9d3cc2470305005c576a02efa9772e18"
```

| Flag | Purpose |
|------|---------|
| `--headroom-release <url>` | Use your own `.whl` instead of the official PyPI package |
| `--headroom-sha256 <hash>` | Verify file integrity before installing (recommended) |

> ⚠️ Without `--headroom-sha256` the installer skips integrity verification.  
> Both flags are compatible with `--full` and `--dry-run`.

### ⚡ Default — Light headroom + DeepClaude

```bash
bash install.sh
```

Installs `headroom-ai[proxy,code,mcp]` (~100 MB), prompting before each step:
- Headroom CLI (via pipx)
- Headroom proxy as a systemd service (auto-start)
- `deepclaude` and `deepclaudehr` terminal commands
- `/headroom_usage` and `/mem` slash commands
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
/mem                     → list memories
/mem <term>              → search memory content
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
       ├── deepclaude ────────────────────────────────► DeepSeek API
       │                                                (direct, no proxy)
       │
       └── deepclaudehr ───► Headroom Proxy (:8787) ──► DeepSeek API
                             │                          (with compression)
                             ├── context compression
                             ├── smart caching
                             ├── code-aware (AST)
                             └── MCP support
```

---

## ⚙️ Environment variables

| Variable | Value | Required |
|----------|-------|:--------:|
| `DEEPSEEK_API_KEY` | `sk-...` | ✅ |
| `OPENROUTER_API_KEY` | `sk-...` | For OpenRouter |
| `FIREWORKS_API_KEY` | `...` | For Fireworks |

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

### Slash commands not showing in Claude Code

```bash
ls -la ~/.claude/commands/*.md ~/.claude/commands/bin/
cat ~/.claude/settings.local.json
# Then: /reload inside Claude Code
```

---

## 📄 License

MIT

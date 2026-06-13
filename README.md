<div align="center">
  <h1>🪄 DeepClaude + Headroom</h1>
  <p><strong>Automated setup of Headroom AI proxy with DeepClaude for Claude Code via DeepSeek API</strong></p>
  <p>
    <img src="https://img.shields.io/badge/headroom-0.25.0-blue" alt="Headroom">
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

## 🚀 Installation

```bash
git clone https://github.com/estrazulas/deepclaude_with_headroom.git
cd deepclaude_with_headroom
```

### Flag combinations

| Flag | Headroom | DeepClaude | Best for |
|------|----------|:----------:|:---------|
| *(none)* | ⚡ Light `[proxy,code,mcp]` *(prompts)* | ❌ | Just proxy + commands |
| `--headroomcomplete` | 🔥 Complete `[all]` *(auto)* | ❌ | All headroom extras |
| `--full` | ⚡ Light `[proxy,code,mcp]` *(prompts)* | ✅ | Proxy + DeepClaude |
| `--headroomcomplete --full` | 🔥 Complete `[all]` *(auto)* | ✅ | Everything |

### ⚡ Default — Light headroom + commands

```bash
bash install.sh
```

Installs `headroom-ai[proxy,code,mcp]` (~100 MB), prompting before each step:
- Headroom CLI (via pipx)
- Headroom proxy as a systemd service (auto-start)
- `/headroom_usage` and `/mem` slash commands
- `DEEPSEEK_API_KEY` in your shell config
- Health check at the end

### 🔥 Complete (all headroom extras)

```bash
bash install.sh --headroomcomplete
```

Installs `headroom-ai[all]` (~2 GB) without prompting — includes vector memory, image support, ML, etc.

### 🚀 Add DeepClaude

```bash
bash install.sh --full                    # light + DeepClaude
bash install.sh --headroomcomplete --full # complete + DeepClaude
```

Adds the `deepclaude` and `deepclaudehr` terminal commands.

---

## 📋 Prerequisites

- **Claude Code** installed (`npm install -g @anthropic-ai/claude-code`)
- **Python 3** + **jq** (`sudo apt install python3 jq`)
- **DeepSeek API Key** — sign up at [platform.deepseek.com](https://platform.deepseek.com)

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

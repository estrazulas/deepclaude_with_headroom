# 🔒 Security Audit Report — Headroom Sanitizer v0.25.1

**Date:** 2026-06-14  
**Repository:** [estrazulas/headroom_sanitizer](https://github.com/estrazulas/headroom_sanitizer)  
**Related:** [estrazulas/deepclaude_with_headroom](https://github.com/estrazulas/deepclaude_with_headroom)  
**Version:** v0.25.1 (fork of [chopratejas/headroom](https://github.com/chopratejas/headroom))  
**Auditor:** Claude Code — Senior Security Engineering  
**Confidence:** 95%

---

## 📊 Executive Summary

| Severity | Original | Pending | Resolved |
|:--------:|:--------:|:-------:|:--------:|
| 🔴 Critical | 0 | 0 | — |
| 🟠 High | 3 | **0** | **3 ✅** |
| 🟡 Medium | 6 | 6 | — |
| 🟢 Low | 4 | 4 | — |
| ℹ️ Info | 3 | 3 | — |
| **Total** | **16** | **13** | **3** |

> ✅ **3 High findings fixed in v0.25.1** — commit `ed92f8a`

---

## 🛠️ Remediation Applied

| Release | Date | Commit |
|---------|:----:|--------|
| **v0.25.1** | 2026-06-14 | `ed92f8a` |

**Fixed files:**
- `headroom/memory/easy.py:118`
- `headroom/memory/backends/direct_mem0.py:102`
- `headroom/memory/backends/mem0.py:60`

**Change:** `neo4j_password: str = "password"` → `neo4j_password: str = ""`

**Wheel:** `headroom_ai-0.25.0-cp310-abi3-manylinux_2_35_x86_64.whl`  
**SHA256:** `63601398d73a3bcfb56e50b6b0d251ce9d3cc2470305005c576a02efa9772e18`  
**Release:** https://github.com/estrazulas/headroom_sanitizer/releases/tag/v0.25.1

---

## 🏆 Positives (Good Practices Found)

- ✅ **No real secrets** found in code or git history
- ✅ **GitGuardian** configured with a well-documented allowlist
- ✅ **.gitignore** exemplary — covers `.env`, `*.pem`, `*.key`, `secrets.json`, `credentials.json`
- ✅ **Fork adds only documentation** (BUILD.md, README, rebuild.sh) — no upstream code changes
- ✅ **All API keys** read from environment variables
- ✅ **Systemd service** (`headroom.service`) with hardening: `IPAddressDeny`, `NoNewPrivileges`, `ProtectSystem`
- ✅ **SHA256 verification** in the installer for custom `.whl` files — supply chain protection
- ✅ **SECURITY.md** with responsible disclosure policy (48h ack, 7d for critical)
- ✅ **Masked keys** in `deepclaude --status` output

---

## ~~🔴 High (3) — RESOLVED ✅~~

### H-1: ~~Default Neo4j password in easy.py~~ ✅

| Field | Value |
|-------|-------|
| **File** | `headroom/memory/easy.py` |
| **Line** | 118 |
| **Status** | ✅ **Resolved in v0.25.1** (`ed92f8a`) |
| **Original code** | `neo4j_password: str = "password"` |
| **Current code** | `neo4j_password: str = ""` |
| **Type** | Hardcoded password |

**Action taken:** Default changed to empty string. `HEADROOM_NEO4J_PASSWORD` must be explicitly set by the operator.

---

### H-2: ~~Default Neo4j password in direct_mem0.py~~ ✅

| Field | Value |
|-------|-------|
| **File** | `headroom/memory/backends/direct_mem0.py` |
| **Line** | 102 |
| **Status** | ✅ **Resolved in v0.25.1** (`ed92f8a`) |
| **Original code** | `neo4j_password: str = "password"` |
| **Current code** | `neo4j_password: str = ""` |
| **Type** | Hardcoded password |

**Action taken:** Default changed to empty string.

---

### H-3: ~~Default Neo4j password in mem0.py~~ ✅

| Field | Value |
|-------|-------|
| **File** | `headroom/memory/backends/mem0.py` |
| **Line** | 60 |
| **Status** | ✅ **Resolved in v0.25.1** (`ed92f8a`) |
| **Original code** | `neo4j_password: str = "password"` |
| **Current code** | `neo4j_password: str = ""` |
| **Type** | Hardcoded password |

**Action taken:** Default changed to empty string.

---

## 🟡 Medium (6) — Pending

### M-1: Default Neo4j credential in docker-compose.yml

| Field | Value |
|-------|-------|
| **File** | `docker-compose.yml` |
| **Line** | 42 |
| **Code** | `NEO4J_AUTH=${NEO4J_AUTH:-neo4j/devpassword}` |
| **Type** | Insecure configuration |

**Risk:** Running `docker-compose up` without setting `NEO4J_AUTH` exposes the graph database with a trivial default credential.

**Action:** Remove the `:-neo4j/devpassword` fallback — force an error if the variable is not set.

---

### M-2: APOC file export/import enabled

| Field | Value |
|-------|-------|
| **File** | `docker-compose.yml` |
| **Line** | 44-46 |
| **Code** | `NEO4J_apoc_export_file_enabled=true` |

**Risk:** The APOC plugin with file export/import allows arbitrary file read/write on the container filesystem. Combined with the default password (M-1), this is an LFI vector.

**Action:** Disable in production: `NEO4J_apoc_export_file_enabled=false`.

---

### M-3: Qdrant without authentication

| Field | Value |
|-------|-------|
| **File** | `docker-compose.yml` |
| **Line** | 25-31 |
| **Ports** | 6333 (REST), 6334 (gRPC) |

**Risk:** Vector database exposed without authentication on the local network.

**Action:** Add `QDRANT__SERVICE__API_KEY` in docker-compose and configure `HEADROOM_QDRANT_API_KEY`.

---

### M-4: Empty Neo4j password default in proxy config

| Field | Value |
|-------|-------|
| **File** | `headroom/proxy/models.py` |
| **Lines** | 265-267 |
| **Code** | `memory_neo4j_password: str = ""` |

**Risk:** Proxy allows startup with an empty Neo4j password. The warning in logs can be ignored.

**Action:** Block startup if `memory_backend == "qdrant-neo4j"` and the password is empty.

---

### M-5: No security hooks in pre-commit

| Field | Value |
|-------|-------|
| **File** | `.pre-commit-config.yaml` |
| **Current hooks** | ruff, mypy, commitlint |

**Risk:** No automated secret detection on commit. Developers may accidentally commit tokens.

**Action:** Add `gitleaks`, `detect-secrets`, or `truffleHog` as a pre-commit hook.

---

### M-6: DEEPSEEK_API_KEY stored in plaintext in shell rc

| Field | Value |
|-------|-------|
| **File** | `deepclaude_with_headroom/install.sh` |
| **Lines** | 303-314 |
| **Code** | `echo "export DEEPSEEK_API_KEY=...\" >> \"$SHELL_RC\"` |

**Risk:** API key stored in plaintext in `.zshrc`/`.bashrc`. Other processes on the system can read it.

**Action:** Consider storing in the OS keyring (`secret-tool`, `kwallet`) or at least in an `.env` file with `600` permissions.

---

## 🟢 Low (4) — Pending

### L-1: API key placeholder in google.py

| File | Line | Issue |
|------|:----:|-------|
| `headroom/providers/google.py` | 14 | `genai.configure(api_key="your-api-key")` — placeholder that sets a dangerous pattern |

**Action:** Replace with an environment variable example: `os.environ['GOOGLE_API_KEY']`.

---

### L-2: Dummy key in proxy.py

| File | Line | Issue |
|------|:----:|-------|
| `headroom/cli/proxy.py` | 924 | `ANTHROPIC_API_KEY="sk-ant-dummy"` — pollutes automated scanners with a real-looking key format |

**Action:** Use a more obvious placeholder like `"set-your-real-key-here"`.

---

### L-3: Proxy exposed without authentication

| File | Line | Issue |
|------|:----:|-------|
| `docker-compose.yml` | 5 | `HEADROOM_HOST=0.0.0.0` on port 8787 without any authentication |

**Action:** Document that `0.0.0.0` is Docker-specific and recommend `127.0.0.1` for direct deployments.

---

### L-4: DEEPSEEK_API_KEY in installer

| File | Line | Issue |
|------|:----:|-------|
| `deepclaude_with_headroom/install.sh` | 303-314 | Key stored in plaintext in shell rc |

**Action:** Consider OS keyring or a restricted `.env` file.

---

## ℹ️ Informational (3)

| # | File | Note |
|:-:|------|------|
| I-1 | `.gitignore` | Exemplary coverage of secret patterns |
| I-2 | `.gitguardian.yaml` | Well-documented allowlist for test tokens |
| I-3 | `SECURITY.md` | Disclosure policy with defined SLA |

---

## 📜 Git History

### headroom_sanitizer (fork)

The fork contains **3 custom commits** (estrazulas) on top of ~970 upstream commits:

| Commit | Files | Risk |
|--------|-------|:----:|
| `8f3e15e` — docs: add build & release guide | `BUILD.md`, `README.md`, `rebuild.sh` | ✅ None |
| `241a2cf` — docs: add sanitized fork quickstart | `README.md` | ✅ None |
| `ed92f8a` — **fix: remove hardcoded Neo4j passwords** | `easy.py`, `direct_mem0.py`, `mem0.py` | ✅ **Security fix** |

> **Conclusion:** No secrets found in history. The third commit is the security fix that removed the default passwords.

### deepclaude_with_headroom

Installer-only repository. All keys are read from environment variables or requested interactively. **No secrets in history.**

---

## 🔧 Installer Analysis (deepclaude_with_headroom)

### Strengths
- Hardcoded API URLs point to public endpoints (api.deepseek.com, openrouter.ai) — acceptable
- `--headroom-sha256` support for custom `.whl` integrity verification
- `headroom.service` with full hardening: `IPAddressDeny=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`, `NoNewPrivileges`, `ProtectSystem`, `PrivateTmp`
- `mask_key()` function in `deepclaude.sh` — displays only `****...` in status commands
- Uninstaller (`uninstall.sh`) completely removes `DEEPSEEK_API_KEY` from shell rc

### Weaknesses
- `DEEPSEEK_API_KEY` stored in plaintext in shell rc (M-6)
- `install.sh` uses `sudo cp` for scripts to `/usr/local/bin` — requires trust in the repository

---

## 📋 Priority Recommendations

### Resolved ✅
1. **🔴** ~~Remove default `"password"` from Neo4j in all 3 files~~ → **v0.25.1**

### Pending — Short Term
2. **🟡** Remove password fallback in `docker-compose.yml` (`NEO4J_AUTH` with no default)
3. **🟡** Disable APOC file export/import in `docker-compose.yml`
4. **🟡** Add authentication to Qdrant in `docker-compose.yml`
5. **🟡** Configure `gitleaks` as a pre-commit hook
6. **🟡** Require non-empty Neo4j password on proxy startup

### Pending — Medium Term
7. **🟢** Replace API key placeholders with environment variable examples
8. **🟢** Consider OS keyring for storing `DEEPSEEK_API_KEY`
9. **ℹ️** Add `*.kdbx`, `*.asc`, `*.gpg` to `.gitignore`
10. **ℹ️** Update `SECURITY.md` to reflect current practices

---

## 🔍 Methodology

- **Static analysis:** grep for secret patterns (API keys, tokens, JWT, passwords, internal endpoints)
- **Git history review:** `git log -p` for commits with secrets, diff of sensitive files
- **CI/CD analysis:** review of GitHub Actions workflows for secret exposure in logs/outputs
- **Dependency audit:** Not performed (scope limited to source code analysis)
- **Dynamic testing:** Not performed (scope limited to static analysis)

---

## 📁 Artifact Structure

```
security_checks/
└── v0.25.1-2026-06-14/
    ├── security-audit-report.json   ← Full JSON report (machine-readable)
    └── report.md                    ← This Markdown report (human-readable)
```

---

*Report generated on 2026-06-14. High findings fixed in v0.25.1 (commit ed92f8a). Re-audit recommended for each new upstream release.*


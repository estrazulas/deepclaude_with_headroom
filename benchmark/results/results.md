# Headroom Benchmark — Detailed Results

**Date:** 2026-07-02
**Model:** DeepSeek V4 Pro (Anthropic-compatible API)
**Proxy:** Headroom 0.27.0.1

---

## Methodology

The benchmark compares token consumption between calling the DeepSeek API
**directly** and routing through the **Headroom proxy**, using identical
prompts.

| Path | Endpoint |
|---|---|
| **Direct** | `POST https://api.deepseek.com/anthropic/v1/messages` |
| **Proxy** | `POST http://localhost:8787/v1/messages` |

Two distinct scenarios simulate real programming sessions. Each runs twice
(direct + proxy), totaling four rounds. Cost is calculated using real
DeepSeek V4 Pro pricing:

| Token type | Price per 1M tokens |
|---|---|
| Input (full price) | $0.44 |
| Input (cache hit) | $0.004 |
| Output | $0.87 |

---

## Scenario DEV — Building a CLI app from scratch

Simulates a developer creating a command-line task manager.

### Turns

| # | Content | Type |
|---|---|---|
| T1 | Create `taskman` script — CLI with argparse, JSON storage, UUIDs | Code generation |
| T2 | Refactor: extract `TaskManager` class with dataclass, logging, CSV export | Refactoring |
| T3 | Write pytest tests with `tmp_path` fixture, 5 scenarios | Testing |
| T4 | Final code review: bugs, security, production readiness, 0–10 score | Review |

### Per-turn tokens

| Turn | Path | Full-price input | Cache hit | Output | Duration |
|---|---|---|---|---|---|
| T1 | Direct | 108 | 0 | 3,632 | 56s |
| T1 | Proxy | 1,572 | 2,688 | 1,726 | 24s |
| T2 | Direct | 165 | 0 | 3,736 | 44s |
| T2 | Proxy | 1,496 | 2,816 | 2,539 | 32s |
| T3 | Direct | 92 | 128 | 2,772 | 44s |
| T3 | Proxy | 595 | 2,944 | 2,980 | 43s |
| T4 | Direct | 134 | 128 | 4,096 | 79s |
| T4 | Proxy | 112 | 2,688 | 4,096 | 48s |

### Aggregated

| | Direct | Proxy | Delta |
|---|---|---|---|
| Input (full price) | 499 | 3,775 | +656% |
| Input (cache hit) | 256 | 11,136 | +4,250% |
| Output | 14,236 | 11,341 | **-20.3%** |
| Total tokens | 14,991 | 26,252 | +75% |
| **Cost** | **$0.0126** | **$0.0116** | **-8.2%** |
| Duration | 223s | 146s | -35% |

---

## Scenario DEBUG — Investigating production bugs

Simulates a developer diagnosing real incidents with logs, stack traces,
and root-cause analysis.

### Turns

| # | Content | Type |
|---|---|---|
| T1 | Production log with a hidden 500 error (~340 lines) | Log analysis |
| T2 | Broken CI pipeline with 3 integration test failures (~100 lines) | Log analysis |
| T3 | Buggy source code: fix AttributeError + deadlock + memory leak | Code fix |
| T4 | Write incident post-mortem | Synthesis |

### Per-turn tokens

| Turn | Path | Full-price input | Cache hit | Output | Duration |
|---|---|---|---|---|---|
| T1 | Direct | 8,749 | 0 | 1,114 | 21s |
| T1 | Proxy | 8,727 | 2,560 | 1,868 | 32s |
| T2 | Direct | 2,445 | 8,704 | 1,061 | 18s |
| T2 | Proxy | 2,423 | 11,264 | 1,205 | 21s |
| T3 | Direct | 297 | 11,136 | 2,887 | 44s |
| T3 | Proxy | 403 | 13,568 | 1,219 | 18s |
| T4 | Direct | 137 | 11,392 | 3,395 | 61s |
| T4 | Proxy | 115 | 13,952 | 1,750 | 30s |

### Aggregated

| | Direct | Proxy | Delta |
|---|---|---|---|
| Input (full price) | 11,628 | 11,668 | +0.3% |
| Input (cache hit) | 31,232 | 41,344 | +32% |
| Output | 8,457 | 6,042 | **-28.6%** |
| Total tokens | 51,317 | 59,054 | +15% |
| **Cost** | **$0.0126** | **$0.0106** | **-16.2%** |
| Duration | 144s | 100s | -31% |

---

## Analysis

### Why the proxy saved money

The key differentiator is the **Output Shaper** (`HEADROOM_OUTPUT_SHAPER=1`).
It controls model response verbosity — essentially a built-in "Caveman" that
makes the model write less without sacrificing technical accuracy (verbosity
level 2, medium).

Output is the most expensive part of the bill: $0.87 per million tokens
vs $0.44 for input. Cutting 20–28% of output more than offsets the metadata
overhead the proxy adds to input.

Additionally, the proxy increased cache hits in both scenarios (+10k cache
tokens in Debug, +11k in Dev), further reducing input cost through the
100× cheaper cache-hit rate ($0.004/M vs $0.44/M).

### Where the proxy excels

- **Verbose output sessions:** the Output Shaper trims filler without
  losing technical depth (verbosity level 2 is safe for code).
- **Repeated context:** the proxy restructures requests with `cache_control`
  breakpoints, maximizing provider-side cache hits.
- **Build/CI logs:** the log compressor (`compressor:log`) extracts only
  relevant errors and warnings from outputs spanning hundreds of lines.

### Where the proxy does not help

- **Cold start (first turn):** with no prior context, the proxy has nothing
  to cache or compress — it only adds metadata overhead.
- **Every turn is unique:** if each message is radically different from the
  previous one, caching is ineffective.
- **Very short prompts (<500 tokens):** metadata overhead is proportionally
  larger than any compression savings.

---

## Proxy Configuration

See `setup_local_hr_gate.sh` and `files/deepclaude/headroom.service` in this
repository for the exact systemd unit used in these benchmarks.

Key parameters:

| Parameter | Value | Purpose |
|---|---|---|
| `--mode` | `token` | Active input compression |
| `--target-ratio` | `0.6` | Kompress keeps ~60% of tokens (safe for code) |
| `--code-aware` | on | AST-based detection to preserve code structure |
| `HEADROOM_OUTPUT_SHAPER` | `1` | Response verbosity control engine |
| `HEADROOM_VERBOSITY_LEVEL` | `2` | Direct but complete (not terse) |
| `HEADROOM_EFFORT_ROUTER` | `1` | Auto-reduce effort on mechanical turns |
| `HEADROOM_PROTECT_TOOL_RESULTS` | `Bash` | Never apply lossy compression to Bash output |

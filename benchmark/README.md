# Headroom Benchmark

Compares token consumption and real cost between calling the DeepSeek API
directly vs routing through the Headroom proxy. Two scenarios simulate
real programming sessions — feature development and production debugging.

## Quick results

| Scenario | Direct | Proxy | Saved |
|---|---|---|---|
| **DEV** (building a CLI app, 4 turns) | $0.0126 | $0.0116 | **-8.2%** |
| **DEBUG** (investigating bugs, 4 turns) | $0.0126 | $0.0106 | **-16.2%** |

Most savings come from the **Output Shaper** — it trims verbose model
responses. Output tokens cost $0.87/M (the most expensive part of the bill);
cutting 20–28% of output more than offsets the proxy's input overhead.

Full breakdown in **[`results/results.md`](results/results.md)** — per-turn
token counts, cost analysis, and when the proxy does (and doesn't) help.

## How to run

```bash
# Prerequisites: Headroom proxy running on localhost:8787
export DEEPSEEK_KEY="sk-..."
export HEADROOM_KEY="hr-..."

python3 benchmark.py
```

Runs four sequential rounds (dev direct, dev proxy, debug direct, debug
proxy), four turns each. Takes ~6–8 minutes. Results are written to
`/tmp/benchmark-results.json` (override with `BENCHMARK_OUTPUT`).

### What the scenarios simulate

```
DEV scenario (building a CLI app):
  T1: Create a taskman script from scratch
  T2: Refactor into a TaskManager class
  T3: Write pytest unit tests
  T4: Final code review

DEBUG scenario (investigating bugs):
  T1: Analyze a production log with a hidden 500 error (~340 lines)
  T2: Diagnose a broken CI pipeline (~100 lines)
  T3: Fix AttributeError + deadlock + memory leak in source code
  T4: Write incident post-mortem
```

### Pricing

DeepSeek V4 Pro (Anthropic-compatible API), July 2026:

| Token type | USD per 1M |
|---|---|
| Input (full price) | $0.44 |
| Input (cache hit) | $0.004 |
| Output | $0.87 |

## Proxy setup

The configuration used in these benchmarks is the default installed by
`setup_local_hr_gate.sh` in the parent repository. Key parameters:

| Parameter | Value | Category |
|---|---|---|
| `--mode token` | Active compression | Input |
| `--target-ratio 0.6` | Kompress keeps ~60% of tokens | Input |
| `--code-aware` | AST-based code detection | Input |
| `HEADROOM_OUTPUT_SHAPER=1` | Verbosity control engine | Output |
| `HEADROOM_VERBOSITY_LEVEL=2` | Direct but complete responses | Output |
| `HEADROOM_EFFORT_ROUTER=1` | Auto-reduce effort on mechanical turns | Output |
| `HEADROOM_PROTECT_TOOL_RESULTS=Bash` | Never compress Bash output lossy | Safety |

See `files/deepclaude/headroom.service` in the parent repo for the full
systemd unit.

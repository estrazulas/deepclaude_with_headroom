#!/usr/bin/env python3
"""Headroom proxy benchmark — 4 turns per scenario, ~6–8 min total runtime.

Compares token consumption and cost between direct DeepSeek API calls
and calls routed through the Headroom proxy, across two real-world
scenarios: feature development and production debugging.

Usage:
  export DEEPSEEK_KEY="sk-..."
  export HEADROOM_KEY="hr-..."
  python3 benchmark.py

Output is written to BENCHMARK_OUTPUT (default: /tmp/benchmark-results.json).
"""
import json, time, os, sys, requests

MODEL = "deepseek-v4-pro"
MAX_TOKENS = 4096
PRICE_IN = 0.44       # USD per 1M input tokens (full price)
PRICE_OUT = 0.87      # USD per 1M output tokens
PRICE_CACHE = 0.004   # USD per 1M input tokens (cache hit)

SYSTEM = "You are a senior software engineer. Answer concisely and thoroughly. Show full code when relevant. Point out security, performance, and best-practice issues."


# ── Log generators (realistic production data) ──────────────────────────────

def log_production_error():
    """Simulated production log — 340 lines, one 500 error buried in the middle."""
    lines = []
    lines.append("=" * 60)
    lines.append("APPLICATION LOG — Production — 2026-07-02 14:23:17 UTC")
    lines.append("=" * 60)
    for i in range(1, 31):
        lines.append("14:23:%02d [INFO] [req-%05d] GET /api/v1/health → 200 OK (2ms)" % (i, 8900 + i))
    for i in range(31, 61):
        lines.append("14:23:%02d [INFO] [req-%05d] POST /api/v1/orders → 201 Created (45ms)" % (i, 8930 + i))
    for i in range(61, 91):
        lines.append("14:24:%02d [INFO] [req-%05d] GET /api/v1/products → 200 OK (8ms)" % (i - 60, 8960 + i))
    for i in range(91, 121):
        lines.append("14:24:%02d [DEBUG] [db-pool] Connection %d acquired, pool: 15/20 active" % (i - 90, i % 20))
    for i in range(121, 151):
        lines.append("14:24:%02d [DEBUG] [cache] Redis GET key:session:%d: hit=True (0.3ms)" % (i - 120, 1000 + i))
    lines.append("14:24:30 [ERROR] [req-9127] POST /api/v1/checkout → 500 Internal Server Error")
    lines.append("14:24:30 [ERROR] [req-9127] Traceback (most recent call last):")
    lines.append('14:24:30 [ERROR] [req-9127]   File "src/api/checkout.py", line 142, in process_checkout')
    lines.append('14:24:30 [ERROR] [req-9127]     payment = await payment_gateway.charge(order.total, method)')
    lines.append('14:24:30 [ERROR] [req-9127]   File "src/gateways/stripe_gateway.py", line 67, in _create_payment_intent')
    lines.append('14:24:30 [ERROR] [req-9127]     metadata={"customer_id": customer.external_id}')
    lines.append("14:24:30 [ERROR] [req-9127] AttributeError: 'Customer' object has no attribute 'external_id'")
    lines.append("14:24:30 [ERROR] [req-9127] Did you mean: 'external_customer_id'?")
    for i in range(182, 220):
        lines.append("14:25:%02d [INFO] [req-%05d] GET /api/v1/products → 200 OK (%dms)" % (i - 150, 9127 + i, 3 + i % 10))
    for i in range(220, 280):
        lines.append("14:26:%02d [DEBUG] [metrics] flush_metrics: sent %d datapoints" % (i - 219, 100 + i))
    lines.append("14:26:35 [WARN] [monitoring] Error rate spike: 0.02% → 2.1% in last 5 min")
    lines.append("14:26:35 [WARN] [monitoring] Affected endpoint: POST /api/v1/checkout")
    for i in range(280, 340):
        lines.append("14:26:%02d [INFO] [req-%05d] GET /api/v1/status → 200 OK (1ms)" % (i - 280, 9400 + i))
    lines.append("=" * 60)
    lines.append("END OF LOG — 347 lines — 1 CRITICAL ERROR — 1 WARNING")
    lines.append("=" * 60)
    return "\n".join(lines)


def log_ci_pipeline():
    """Simulated CI pipeline log — ~100 lines, 3 integration test failures."""
    lines = []
    lines.append("=" * 50)
    lines.append("CI PIPELINE #5281 — merge_request !1427 (feature/payment-v2 → main)")
    lines.append("=" * 50)
    lines.append("[STAGE 1/5: setup]       OK passed (12.4s)")
    lines.append("[STAGE 2/5: lint]        OK passed (8.1s)")
    lines.append("[STAGE 3/5: unit-tests]  OK  247 tests passed (45.2s)")
    lines.append("[STAGE 4/5: integration-tests]")
    for i in range(96, 131):
        lines.append("  [%03d] PASSED tests/integration/test_api_%d.py (1.%ds)" % (i, i, i % 5))
    lines.append("  [131] FAILED test_payment_flow.py::test_stripe_charge → Expected 200, got 500")
    lines.append("  [131] Response: error=internal_error, detail=Customer has no external_id")
    for i in range(132, 152):
        lines.append("  [%03d] PASSED tests/integration/test_webhooks_%d.py (1.%ds)" % (i, i, i % 3))
    lines.append("  [152] FAILED test_refund_flow.py::test_full_refund → Webhook timeout 30s")
    lines.append("  [152] Root cause: same AttributeError on external_id")
    for i in range(153, 173):
        lines.append("  [%03d] PASSED tests/integration/test_endpoints_%d.py (0.%ds)" % (i, i, i % 4))
    lines.append("  [173] FAILED test_customer_sync.py::test_sync_to_stripe → missing external_id")
    lines.append("  [173] Migration 0042 renamed column external_id → external_customer_id")
    lines.append("  [173] but 17 references still use the old name")
    for i in range(174, 194):
        lines.append("  [%03d] PASSED tests/integration/test_validators_%d.py (0.%ds)" % (i, i, i % 3))
    lines.append("FAILED integration-tests (97/100 passed, 3 failed)")
    lines.append("=" * 50)
    lines.append("PIPELINE RESULT: FAILED — 3 failures — Root cause: migration 0042")
    lines.append("=" * 50)
    return "\n".join(lines)


# ── Turn definitions ────────────────────────────────────────────────────────

DEV_TURNS = [
    {
        "role": "user",
        "content": (
            "Create a Python script `taskman` — a CLI task manager with argparse "
            "subcommands (add, list, done, delete). Store tasks as JSON in "
            "~/.taskman/tasks.json. Each task has: id (UUID), title, description, "
            "status (todo/done), created_at, done_at. Use pathlib, dataclasses, uuid. "
            "Show the full code."
        ),
    },
    {
        "role": "user",
        "content": (
            "Refactor taskman: extract a TaskManager class with add(), list(), "
            "mark_done(), delete(), export_csv(). Use @dataclass for Task, logging "
            "module, robust error handling. Show the complete class."
        ),
    },
    {
        "role": "user",
        "content": (
            "Write pytest tests for TaskManager: test_add_task, "
            "test_list_filter_status, test_mark_done, test_delete, "
            "test_corrupted_json_recovers. Use tmp_path fixture. "
            "Show the full test code."
        ),
    },
    {
        "role": "user",
        "content": (
            "Review all the taskman code. Any bugs? Security issues? "
            "Is it production-ready? Rate it 0–10."
        ),
    },
]

DEBUG_TURNS = [
    {
        "role": "user",
        "content": (
            "Our production app started returning 500 errors on the checkout "
            "endpoint. Analyze this log:\n\n```\n%s\n```\n\n"
            "1. What is the error and root cause?\n"
            "2. Impact assessment?\n"
            "3. Suggest a hotfix and a permanent fix."
        ) % log_production_error(),
    },
    {
        "role": "user",
        "content": (
            "The CI pipeline broke after merging feature/payment-v2. Analyze:\n\n"
            "```\n%s\n```\n\n"
            "1. What is the common denominator across the 3 failures?\n"
            "2. Prioritized action plan."
        ) % log_ci_pipeline(),
    },
    {
        "role": "user",
        "content": (
            "I found the buggy code. Analyze and fix it:\n\n"
            "```python\n"
            "class OrderService:\n"
            "    def __init__(self):\n"
            "        self._payment_locks: dict[str, threading.Lock] = {}\n"
            "\n"
            "    def process_checkout(self, order: Order) -> PaymentResult:\n"
            "        lock = self._lock_payment(order.payment_id)\n"
            "        with lock:\n"
            '            charge = self.stripe.charge(order.total,\n'
            '                metadata={"customer_id": order.customer.external_id})\n'
            "            # BUG: external_id does not exist on Customer\n"
            "            if order.coupon:\n"
            "                self.process_refund(order, order.total - order.discounted_total)\n"
            "            return PaymentResult(success=True, charge_id=charge.id)\n"
            "\n"
            "    def process_refund(self, order: Order, amount: Decimal) -> RefundResult:\n"
            "        lock = self._lock_payment(order.payment_id)  # DEADLOCK: same lock re-acquired\n"
            "        with lock:\n"
            "            refund = self.stripe.refund(order.payment_id, amount)\n"
            "            return RefundResult(success=True, refund_id=refund.id)\n"
            "```\n\n"
            "1. Fix the AttributeError (1 line).\n"
            "2. Fix the deadlock (process_refund called inside process_checkout with the same lock).\n"
            "3. The _payment_locks dict grows indefinitely — fix that too.\n"
            "Show the complete corrected code."
        ),
    },
    {
        "role": "user",
        "content": (
            "Based on everything we investigated (500 error, broken CI, "
            "migration 0042, deadlock), write a one-page post-mortem:\n"
            "- Summary (2–3 sentences)\n"
            "- Timeline\n"
            "- Root cause\n"
            "- Impact\n"
            "- Corrective actions (short / medium / long term)\n"
            "- 3 lessons learned"
        ),
    },
]


# ── API helpers ─────────────────────────────────────────────────────────────

def call_api(api_url, token, messages, turn):
    headers = {
        "x-api-key": token,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
    body = {
        "model": MODEL,
        "max_tokens": MAX_TOKENS,
        "temperature": 0.7,
        "system": SYSTEM,
        "messages": messages,
    }
    t0 = time.monotonic()
    try:
        r = requests.post(api_url, headers=headers, json=body, timeout=180)
        ms = (time.monotonic() - t0) * 1000
    except Exception as e:
        return {"error": str(e)}
    if r.status_code != 200:
        return {"error": "HTTP %d: %s" % (r.status_code, r.text[:200])}
    d = r.json()
    u = d.get("usage", {})
    return {
        "in": u.get("input_tokens", 0),
        "out": u.get("output_tokens", 0),
        "cache": u.get("cache_read_input_tokens", 0),
        "ms": round(ms, 1),
        "stop": d.get("stop_reason", "?"),
    }


def run_scenario(label, scenario, base_url, token):
    api = "%s/v1/messages" % base_url.rstrip("/")
    turns = DEV_TURNS if scenario == "dev" else DEBUG_TURNS
    print("\n" + "─" * 55)
    print(" %s | %s | %s" % (label, scenario, api))
    print("─" * 55)

    history = []
    total_in = total_out = total_cache = total_ms = 0

    for i, msg in enumerate(turns):
        history.append(msg)
        chars = sum(len(m["content"]) for m in history)
        sys.stdout.write("  T%d/%d (%d chars)... " % (i + 1, len(turns), chars))
        sys.stdout.flush()

        r = call_api(api, token, history, i + 1)
        if "error" in r:
            print("ERROR: %s" % r["error"])
            break

        history.append({"role": "assistant", "content": "[%d tokens]" % r["out"]})
        total_in += r["in"]
        total_out += r["out"]
        total_cache += r["cache"]
        total_ms += r["ms"]
        print("in=%d out=%d cache=%d (%dms)" % (r["in"], r["out"], r["cache"], r["ms"]))

    real_in = total_in + total_cache
    total_tokens = real_in + total_out
    cost = (
        (total_in / 1e6) * PRICE_IN +
        (total_cache / 1e6) * PRICE_CACHE +
        (total_out / 1e6) * PRICE_OUT
    )

    print("  " + "─" * 50)
    print("  Input: %d (+%d cache) | Output: %d" % (total_in, total_cache, total_out))
    print("  Total: %d tokens | Cost: $%.4f | %ds" % (total_tokens, cost, total_ms / 1000))

    # Show DeepSeek balance if using a direct API key
    if "sk-" in (token or ""):
        try:
            bal = requests.get(
                "https://api.deepseek.com/user/balance",
                headers={"Authorization": "Bearer %s" % token},
                timeout=10,
            )
            if bal.status_code == 200:
                bd = bal.json()
                balance = bd["balance_infos"][0]["total_balance"]
                print("  DeepSeek balance: $%s" % balance)
        except Exception:
            pass

    return {
        "label": label,
        "scenario": scenario,
        "total_in": total_in,
        "total_cache": total_cache,
        "total_out": total_out,
        "total_real_in": real_in,
        "total_tokens": total_tokens,
        "cost": cost,
        "duration_s": total_ms / 1000,
    }


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    deepseek_key = os.environ.get("DEEPSEEK_KEY", "")
    headroom_key = os.environ.get("HEADROOM_KEY", "")

    results = []

    if deepseek_key:
        results.append(run_scenario("Dev Direct", "dev", "https://api.deepseek.com/anthropic", deepseek_key))
    if headroom_key:
        results.append(run_scenario("Dev Proxy", "dev", "http://localhost:8787", headroom_key))
    if deepseek_key:
        results.append(run_scenario("Debug Direct", "debug", "https://api.deepseek.com/anthropic", deepseek_key))
    if headroom_key:
        results.append(run_scenario("Debug Proxy", "debug", "http://localhost:8787", headroom_key))

    # ── Comparison ──
    print("\n" + "=" * 60)
    print(" FINAL COMPARISON")
    print("=" * 60)

    comparisons = [
        ("DEV", "Dev Direct", "Dev Proxy"),
        ("DEBUG", "Debug Direct", "Debug Proxy"),
    ]
    for scenario, direct_label, proxy_label in comparisons:
        d = next((r for r in results if r["label"] == direct_label), None)
        p = next((r for r in results if r["label"] == proxy_label), None)
        if not d or not p:
            continue

        dc = d["cost"]
        pc = p["cost"]
        diff = pc - dc
        pct = (diff / dc * 100) if dc else 0
        sign = "+" if diff > 0 else ""

        if diff < -0.001:
            verdict = "saved"
            emoji = "+"
        elif diff > 0.001:
            verdict = "cost more"
            emoji = "-"
        else:
            verdict = "neutral"
            emoji = " "

        print("\n  %s: %s$%.4f (%s%.1f%%) — proxy %s" % (scenario, sign, diff, sign, pct, verdict))
        print("    Direct: $%.4f (%s tokens) | Proxy: $%.4f (%s tokens)" % (
            dc, f"{d['total_tokens']:,}", pc, f"{p['total_tokens']:,}"))

    out_path = os.environ.get("BENCHMARK_OUTPUT", "/tmp/benchmark-results.json")
    with open(out_path, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False, default=str)
    print("\nSaved: %s" % out_path)


if __name__ == "__main__":
    main()

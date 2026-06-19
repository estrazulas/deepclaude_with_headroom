---
title: /headroom_usage
description: Display Headroom proxy savings statistics (compression, cache, tokens saved)
argument-hint: [-v | -j | -p]
---

!`/home/estrazulas/.claude/commands/bin/headroom_usage $ARGUMENTS`

Display a dashboard with savings statistics from the Headroom proxy running at `localhost:8787`.

## Uso

```
/headroom_usage          → formatted dashboard
/headroom_usage -v       → full /stats JSON
/headroom_usage -j       → raw JSON
/headroom_usage -p       → Prometheus metrics
```

## Displayed data

- Current session (requests, tokens, savings %)
- Lifetime accumulated
- Compression applied (average, best case, strategies)
- Cache hit rate
- Performance (latency, Headroom overhead, TTFB)
- Models used
- Last requests with savings per request
- Estimated savings in USD (if configured)

## Requirements

- Headroom proxy running at `localhost:8787`
  → Check with `systemctl --user status headroom.service`
- `jq` installed for JSON formatting

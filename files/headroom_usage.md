---
title: /headroom_usage
description: Exibe estatísticas de economia do Headroom proxy (compressão, cache, tokens salvos)
argument-hint: [-v | -j | -p]
---

!`/home/estrazulas/.claude/commands/bin/headroom_usage $ARGUMENTS`

Exibe um dashboard com as estatísticas de economia do Headroom proxy rodando em `localhost:8787`.

## Uso

```
/headroom_usage          → dashboard formatado
/headroom_usage -v       → JSON completo do /stats
/headroom_usage -j       → JSON bruto
/headroom_usage -p       → métricas no formato Prometheus
```

## Dados exibidos

- Sessão atual (requests, tokens, economia %)
- Lifetime acumulado
- Compressão aplicada (média, melhor caso, estratégias)
- Cache hit rate
- Performance (latência, overhead do Headroom, TTFB)
- Modelos usados
- Últimas requisições com savings por req
- Estimativa de economia em USD (se configurada)

## Requisitos

- Headroom proxy rodando em `localhost:8787`
  → Verifique com `systemctl --user status headroom.service`
- `jq` instalado para formatação do JSON

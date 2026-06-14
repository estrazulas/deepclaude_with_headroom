# DeepClaude + Headroom

## Regras de Memória

### Auto Memory (compartilhada entre sessões)
Usar `memory_save` apenas quando eu pedir explicitamente por "memória compartilhada", "salva em memória geral", ou "lembre disso globalmente".

### File-based Memory (comando `/mem`)
Usar por padrão para qualquer informação do projeto. Salvar em:

```
~/.claude/projects/-home-estrazulas/memory/
```

Sempre atualizar o `MEMORY.md` lá ao adicionar um arquivo.

### Dúvida
Sempre perguntar se não souber onde salvar.

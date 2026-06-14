# 🔒 Security Audit Report — Headroom Sanitizer v0.25.0

**Data:** 2026-06-14  
**Repositório:** [estrazulas/headroom_sanitizer](https://github.com/estrazulas/headroom_sanitizer)  
**Relacionado:** [estrazulas/deepclaude_with_headroom](https://github.com/estrazulas/deepclaude_with_headroom)  
**Versão:** v0.25.0 (fork do [chopratejas/headroom](https://github.com/chopratejas/headroom))  
**Auditor:** Claude Code — Engenharia de Segurança Sênior  
**Confiança:** 95%

---

## 📊 Resumo Executivo

| Severidade | Contagem | Descrição |
|:----------:|:--------:|-----------|
| 🔴 Critical | 0 | Nenhum secret ativo exposto |
| 🟠 High | 3 | Senhas padrão Neo4j no código-fonte |
| 🟡 Medium | 6 | Configurações inseguras, falta de automação de segurança |
| 🟢 Low | 4 | Práticas inseguras sem exposição direta |
| ℹ️ Info | 3 | Observações e boas práticas |
| **Total** | **16** | |

---

## 🏆 Positivos (Boas Práticas Identificadas)

- ✅ **Nenhum secret real** encontrado no código ou histórico do git
- ✅ **GitGuardian** configurado com allowlist criteriosa e documentada
- ✅ **.gitignore** exemplar — cobre `.env`, `*.pem`, `*.key`, `secrets.json`, `credentials.json`
- ✅ **Fork adiciona apenas documentação** (BUILD.md, README, rebuild.sh) — sem modificar código-fonte upstream
- ✅ **Todas as chaves de API** lidas de variáveis de ambiente
- ✅ **Systemd service** (`headroom.service`) com hardening: `IPAddressDeny`, `NoNewPrivileges`, `ProtectSystem`
- ✅ **Verificação SHA256** no instalador para `.whl` customizados — proteção supply chain
- ✅ **SECURITY.md** com política de disclosure responsável (48h acknowledge, 7d para críticos)
- ✅ **Chaves mascaradas** na saída do comando `deepclaude --status`

---

## 🔴 Altos (3) — Corrigir com Urgência

### H-1: Senha padrão Neo4j no módulo easy.py

| Campo | Valor |
|-------|-------|
| **Arquivo** | `headroom/memory/easy.py` |
| **Linha** | 118 |
| **Código** | `neo4j_password: str = "password"` |
| **Tipo** | Senha hardcoded |
| **Risco** | Deploy com backend de memória Neo4j sem sobrescrever a senha expõe o banco a acesso local não autorizado |

**Ação:** Alterar default para string vazia e emitir erro se não configurado.

---

### H-2: Senha padrão Neo4j no backend direct_mem0.py

| Campo | Valor |
|-------|-------|
| **Arquivo** | `headroom/memory/backends/direct_mem0.py` |
| **Linha** | 102 |
| **Código** | `neo4j_password: str = "password"` |
| **Tipo** | Senha hardcoded |
| **Risco** | Mesmo risco de H-1, propagado para backend alternativo de memória |

**Ação:** Mesma de H-1.

---

### H-3: Senha padrão Neo4j no backend mem0.py

| Campo | Valor |
|-------|-------|
| **Arquivo** | `headroom/memory/backends/mem0.py` |
| **Linha** | 60 |
| **Código** | `neo4j_password: str = "password"` |
| **Tipo** | Senha hardcoded |
| **Risco** | Terceira ocorrência do mesmo padrão, agora no backend principal |

**Ação:** Consolidar todos os defaults em uma definição única e exigir configuração via env var.

---

## 🟡 Médios (6) — Corrigir Prioritariamente

### M-1: Credencial default Neo4j no docker-compose.yml

| Campo | Valor |
|-------|-------|
| **Arquivo** | `docker-compose.yml` |
| **Linha** | 42 |
| **Código** | `NEO4J_AUTH=${NEO4J_AUTH:-neo4j/devpassword}` |
| **Tipo** | Configuração insegura |

**Risco:** `docker-compose up` sem configurar `NEO4J_AUTH` expõe o banco gráfico com credencial trivial.

**Ação:** Remover fallback `:-neo4j/devpassword` — forçar erro se variável não definida.

---

### M-2: APOC file export/import habilitado

| Campo | Valor |
|-------|-------|
| **Arquivo** | `docker-compose.yml` |
| **Linha** | 44-46 |
| **Código** | `NEO4J_apoc_export_file_enabled=true` |

**Risco:** Plugin APOC com export/import de arquivos permite leitura/escrita arbitrária no filesystem do container. Combinado com senha default (M-1), é vetor de LFI.

**Ação:** Desabilitar em produção: `NEO4J_apoc_export_file_enabled=false`.

---

### M-3: Qdrant sem autenticação

| Campo | Valor |
|-------|-------|
| **Arquivo** | `docker-compose.yml` |
| **Linha** | 25-31 |
| **Portas** | 6333 (REST), 6334 (gRPC) |

**Risco:** Banco vetorial exposto sem autenticação na rede local.

**Ação:** Adicionar `QDRANT__SERVICE__API_KEY` no docker-compose e configurar `HEADROOM_QDRANT_API_KEY`.

---

### M-4: Config padrão Neo4j vazia no proxy

| Campo | Valor |
|-------|-------|
| **Arquivo** | `headroom/proxy/models.py` |
| **Linhas** | 265-267 |
| **Código** | `memory_neo4j_password: str = ""` |

**Risco:** Proxy permite startup com senha vazia para o Neo4j. O warning no log pode ser ignorado.

**Ação:** Bloquear startup se `memory_backend == "qdrant-neo4j"` e senha estiver vazia.

---

### M-5: Sem hooks de segurança no pre-commit

| Campo | Valor |
|-------|-------|
| **Arquivo** | `.pre-commit-config.yaml` |
| **Hooks atuais** | ruff, mypy, commitlint |

**Risco:** Nenhuma detecção automática de secrets no commit. Desenvolvedores podem commitar tokens acidentalmente.

**Ação:** Adicionar `gitleaks`, `detect-secrets` ou `truffleHog` como hook de pre-commit.

---

### M-6: DEEPSEEK_API_KEY em texto plano no shell rc

| Campo | Valor |
|-------|-------|
| **Arquivo** | `deepclaude_with_headroom/install.sh` |
| **Linhas** | 303-314 |
| **Código** | `echo "export DEEPSEEK_API_KEY=...\" >> \"$SHELL_RC\"` |

**Risco:** Chave de API armazenada em texto plano em `.zshrc`/`.bashrc`. Outros processos no sistema podem ler.

**Ação:** Considerar armazenar em keyring do SO (`secret-tool`, `kwallet`) ou ao menos em `.env` com permissões `600`.

---

## 🟢 Baixos (4) — Boas Práticas

### L-1: Placeholder de API key no google.py

| Arquivo | Linha | Problema |
|---------|:-----:|----------|
| `headroom/providers/google.py` | 14 | `genai.configure(api_key="your-api-key")` — placeholder que estabelece padrão perigoso |

**Ação:** Substituir por exemplo com `os.environ['GOOGLE_API_KEY']`.

---

### L-2: Chave dummy no proxy.py

| Arquivo | Linha | Problema |
|---------|:-----:|----------|
| `headroom/cli/proxy.py` | 924 | `ANTHROPIC_API_KEY="sk-ant-dummy"` — polui scanners automatizados com formato de chave real |

**Ação:** Usar valor mais óbvio como `"set-your-real-key-here"`.

---

### L-3: Proxy exposto sem autenticação

| Arquivo | Linha | Problema |
|---------|:-----:|----------|
| `docker-compose.yml` | 5 | `HEADROOM_HOST=0.0.0.0` na porta 8787 sem qualquer autenticação |

**Ação:** Documentar que 0.0.0.0 é específico para Docker e recomendar `127.0.0.1` em deploys diretos.

---

### L-4: Discrepância SECURITY.md vs código

| Arquivo | Problema |
|---------|----------|
| `SECURITY.md:60` | Afirma "Never store or log API keys", mas há senhas hardcoded nos módulos de memória |

**Ação:** Atualizar SECURITY.md ou corrigir os defaults.

---

## 📜 Histórico do Git

### headroom_sanitizer (fork)

O fork contém **2 commits próprios** (estrazulas) sobre ~970 commits do upstream:

| Commit | Arquivos | Risco |
|--------|----------|:-----:|
| `241a2cf` — docs: add sanitized fork build & release quickstart | `README.md` | ✅ Nenhum |
| `8f3e15e` — docs: add build & release guide for internal use | `BUILD.md`, `README.md`, `rebuild.sh` | ✅ Nenhum |

> **Conclusão:** Nenhum secret encontrado no histórico. Os commits do fork são exclusivamente documentação e script de build.

### deepclaude_with_headroom

Repositório pequeno (9 commits) com scripts de instalação. Todas as chaves são lidas de variáveis de ambiente ou solicitadas interativamente. **Nenhum secret no histórico.**

---

## 🔧 Análise dos Instaladores (deepclaude_with_headroom)

### Pontos Fortes
- URLs de API hardcoded são endpoints públicos (api.deepseek.com, openrouter.ai) — aceitável
- Suporte a `--headroom-sha256` para verificação de integridade de `.whl` customizados
- `headroom.service` com hardening completo: `IPAddressDeny=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`, `NoNewPrivileges`, `ProtectSystem`, `PrivateTmp`
- Função `mask_key()` no `deepclaude.sh` — exibe apenas `****...` nos comandos de status
- Script de desinstalação (`uninstall.sh`) remove completamente `DEEPSEEK_API_KEY` do shell rc

### Pontos de Atenção
- `DEEPSEEK_API_KEY` armazenada em texto plano no shell rc (M-6)
- Script `install.sh` faz `sudo cp` de scripts para `/usr/local/bin` — requer confiança no repositório

---

## 📋 Recomendações Prioritárias

### Imediatas (antes do deploy)
1. **🔴** Remover senha padrão `"password"` do Neo4j nos 3 arquivos (`easy.py`, `direct_mem0.py`, `mem0.py`)
2. **🟡** Remover fallback de senha no `docker-compose.yml` (`NEO4J_AUTH` sem default)
3. **🟡** Desabilitar APOC file export/import no `docker-compose.yml`

### Curto Prazo
4. **🟡** Adicionar autenticação ao Qdrant no `docker-compose.yml`
5. **🟡** Configurar `gitleaks` como hook de pre-commit
6. **🟡** Exigir senha Neo4j não-vazia no startup do proxy

### Médio Prazo
7. **🟢** Substituir placeholders de API keys por exemplos com variáveis de ambiente
8. **🟢** Considerar keyring do SO para armazenar `DEEPSEEK_API_KEY`
9. **ℹ️** Adicionar `*.kdbx`, `*.asc`, `*.gpg` ao `.gitignore`

---

## 🔍 Metodologia

- **Análise estática:** grep de padrões de secrets (API keys, tokens, JWT, senhas, endpoints internos)
- **Revisão de git history:** `git log -p` para commits com secrets, diff de arquivos sensíveis
- **Análise de CI/CD:** revisão de GitHub Actions workflows para exposição de secrets em logs/outputs
- **Auditoria de dependências:** Não realizada (escopo limitado a análise de código-fonte)
- **Testes dinâmicos:** Não realizados (escopo limitado a análise estática)

---

## 📁 Estrutura dos Artefatos

```
security_checks/
└── v0.25.0-2026-06-14/
    ├── security-audit-report.json   ← Relatório completo em JSON (máquina)
    └── report.md                    ← Este relatório em Markdown (leitura humana)
```

---

*Relatório gerado em 2026-06-14 por Claude Code. Recomenda-se reauditar a cada nova release do upstream.*

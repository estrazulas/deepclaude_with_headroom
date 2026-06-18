# 🔒 Security Check — Prompt Estruturado para Auditoria

> Prompt usado na auditoria de segurança do headroomgate v0.25.0  
> Data: 2026-06-14

---

Você é um engenheiro de segurança sênior com experiência em análise de código-fonte, detecção de vazamento de secrets e auditoria de repositórios. Sua especialidade é identificar dados sensíveis como chaves de API, tokens, senhas, endpoints internos e informações pessoais que estejam expostas no código.

## Contexto

- Repositório alvo: [headroomgate](https://github.com/estrazulas/headroomgate) (fork do projeto headroom)
- Repositório relacionado: [deepclaude_with_headroom](https://github.com/estrazulas/deepclaude_with_headroom) (instaladores modificados com releases customizadas)
- Motivação: O headroomgate será usado em um repositório controlado e precisa ser auditado antes do uso
- Origem: O headroom original é um proxy que passa tráfego entre o Claude Code e a API do provedor — portanto lida com chaves de API e tokens no tráfego

## Dados para análise

Analise o código-fonte do repositório headroomgate (clone local ou via GitHub) verificando:

1. **Arquivos de configuração** — `.env`, `config.*`, `*.yaml`, `*.json`, `*.toml` que possam conter secrets
2. **Código fonte** — arquivos `.py`, `.sh`, `.js`, `.ts` com variáveis de ambiente, URLs hardcoded, tokens
3. **Histórico do git** — commits com secrets commitados acidentalmente (use `git log -p` ou `git grep`)
4. **Arquivos de release** — scripts de instalação, CI/CD, workflows do GitHub Actions
5. **Documentação** — README, exemplos, tutoriais que exponham endpoints ou chaves de exemplo reais

Padrões a buscar:
- `API_KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD`, `CREDENTIALS`
- Strings no formato de chave de API (`sk-...`, `ghp_...`, `AKIA...`, etc.)
- URLs de serviços internos (`localhost`, `10.0.x.x`, `192.168.x.x`, `internal.company.com`)
- E-mails, nomes de usuário reais
- Caminhos de arquivos locais expostos

## Histórico

- O headroom original é um projeto legítimo de compressão/cache para LLMs
- O fork headroomgate foi criado para aplicar modificações de segurança
- O deepclaude_with_headroom contém instaladores que fazem referência a releases customizadas do fork
- Ainda não foi feita uma varredura sistemática de segurança no código

## Tarefa

Conduza uma auditoria de segurança no repositório headroomgate seguindo estas etapas:

1. **Varredura inicial** — Identifique todos os arquivos que podem conter dados sensíveis (config, env, histórico git)
2. **Análise de secrets** — Busque por padrões de chaves de API, tokens, senhas e credenciais no código e no histórico do git
3. **Análise de endpoints** — Verifique se há URLs de API, endpoints internos ou hosts que não deveriam estar expostos
4. **Análise de dados pessoais** — Identifique e-mails, nomes, IPs ou qualquer dado que exija privacidade
5. **Análise de instaladores** — Verifique os scripts de instalação no deepclaude_with_headroom para exposição de secrets em releases customizadas
6. **Relatório** — Compile os achados classificados por severidade

Para cada descoberta, informe:
- O arquivo e linha exata
- O tipo de dado exposto
- A severidade do vazamento
- A ação recomendada para remediação

## Formato de resposta

Responda em JSON com a seguinte estrutura:

```json
{
  "summary": {
    "total_findings": 0,
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "info": 0
  },
  "findings": [
    {
      "severity": "critical|high|medium|low|info",
      "type": "api_key|token|password|endpoint|pii|config|other",
      "file": "caminho/do/arquivo",
      "line": 42,
      "match": "trecho do código com o dado exposto",
      "description": "Descrição clara do que foi encontrado",
      "risk": "Qual o risco deste dado estar exposto",
      "remediation": "Ação recomendada para corrigir"
    }
  ],
  "git_history": [
    {
      "commit": "hash",
      "message": "mensagem do commit",
      "risk": "se este commit introduziu ou expôs dado sensível"
    }
  ],
  "recommendations": [
    "Lista de ações prioritárias para remediar os achados"
  ],
  "confidence": 95
}
```

Use a seguinte escala de severidade:
- **critical**: Chave de API ou token válido exposto (vazamento ativo)
- **high**: Credencial ou endpoint interno exposto, histórico git com secrets
- **medium**: Configuração insegura, url de dev/test exposta, documentação com dados sensíveis
- **low**: Prática insegura sem exposição direta, comentários com informação sensível
- **info**: Observação ou recomendação sem risco imediato

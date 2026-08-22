# Spec-Driven de Ajustes — Meta Ads MCP

> Data: 2026-08-15
> Escopo: análise completa de credenciais, código, segurança e deploy (local + Vercel)

---

## 1. Inventário de Elementos

| Arquivo | Papel | Estado atual |
|---|---|---|
| `server.py` | Servidor MCP (stdio + HTTP) | Funcional com ressalvas |
| `api/index.py` | Entrypoint ASGI para Vercel | Correto |
| `vercel.json` | Roteamento Vercel | Incompleto |
| `requirements.txt` | Dependências Python | Atualizado |
| `.env.local` | Credenciais locais | Preenchido |
| `.env.example` | Template de credenciais | Desatualizado |
| `.gitignore` | Proteção de segredos | Correto |
| `runtime.txt` | Versão Python no Vercel | **AUSENTE** |

---

## 2. Diagnóstico Completo por Elemento

### 2.1 `.env.local`

```
META_ACCESS_TOKEN=EAAQ...  ✓ Token real presente
META_APP_ID=<app_id>  ⚠️  Definido mas não consumido pelo código
META_CLIENT_ID=8c97fb3...     ⚠️  Definido mas não consumido pelo código
MCP_AUTH_TOKEN=-O9os16...  ✓ Gerado e preenchido
```

**Problema A — `META_APP_ID` e `META_CLIENT_ID` são variáveis mortas**
Estão no `.env.local` mas nenhum `os.getenv("META_APP_ID")` existe no código.
Decisão necessária: usar para validação de token ou remover.

---

### 2.2 `server.py`

**Problema B — `load_dotenv` usa caminho relativo ao CWD**

```python
# linha 19 — atual (frágil)
load_dotenv(".env.local")

# Se o usuário rodar de outro diretório, o arquivo não é encontrado:
# cd /tmp && python /caminho/server.py  → META_ACCESS_TOKEN = None
```

Solução: usar caminho absoluto relativo ao próprio arquivo.

---

**Problema C — `special_ad_categories` enviado como string JSON**

```python
# linha 173 — atual
"special_ad_categories": "[]",
```

A Meta Marketing API espera este campo como array no body do POST.
Enviado como form-data com valor `"[]"` (string literal), pode causar erro
`(#100) special_ad_categories must be a list`.

---

**Problema D — `_token()` não tem cache**

```python
# chamada a cada request
payload["access_token"] = _token()
```

`os.getenv()` é barato, mas o padrão defensivo é ler uma vez e reutilizar.
Baixa prioridade — System User Tokens não mudam em runtime.

---

**Problema E — Sem logging configurado**

O docstring do arquivo avisa "use logging", mas nenhum `logging.basicConfig()`
foi definido. Erros da Graph API são silenciosos no stdio local.

---

### 2.3 `vercel.json`

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/api/index" }]
}
```

**Problema F — Sem especificação de runtime Python**

Sem `runtime.txt` nem `builds` config, a Vercel usa o Python padrão da plataforma
(atualmente 3.9 em muitas regiões). O `fastmcp==3.4.5` exige Python ≥ 3.10.
Resultado: build pode falhar silenciosamente ou gerar erros de sintaxe.

---

**Problema G — `builds` ausente**

A auto-detecção da Vercel para ASGI Python funciona, mas é frágil.
Sem `builds` explícito, uma mudança de plataforma pode quebrar sem aviso.

---

### 2.4 `requirements.txt`

```
fastmcp==3.4.5
httpx==0.28.1
python-dotenv==1.1.1  ← adicionado
```

**Problema H — `starlette` não declarado explicitamente**

`api/index.py` importa `from starlette.responses import JSONResponse`.
`starlette` vem como dependência transitiva do `fastmcp`, mas não está
declarado explicitamente. Se o fastmcp mudar de dependências, o deploy quebra.

---

### 2.5 `.env.example`

```
MCP_AUTH_TOKEN=   ← vazio, sem instrução de formato
```

**Problema I — Template não reflete as variáveis reais**

`META_APP_ID` e `META_CLIENT_ID` existem no `.env.local` mas não no `.env.example`.
O template está desatualizado para quem clonar o projeto.

---

### 2.6 Vercel Secrets (deploy)

**Problema J — Nenhuma variável cadastrada no Vercel ainda**

O servidor no Vercel depende de `os.getenv()` que lê do ambiente injetado.
Sem os secrets cadastrados, o deploy sobe mas todas as chamadas falham.

Variáveis obrigatórias para o Vercel:
- `META_ACCESS_TOKEN` — mesmo valor do `.env.local`
- `MCP_AUTH_TOKEN` — mesmo valor do `.env.local`

Variáveis opcionais (se forem ser usadas no código):
- `META_APP_ID`
- `META_CLIENT_ID`

---

## 3. Especificações de Ajuste

### ADJ-01 — Corrigir caminho do `load_dotenv`
**Prioridade:** Alta | **Status:** Pendente
**Arquivo:** `server.py:19`

```python
# ANTES
load_dotenv(".env.local")

# DEPOIS
from pathlib import Path
load_dotenv(Path(__file__).parent / ".env.local")
```

**Critério de aceitação:** `python /qualquer/caminho/server.py` carrega as variáveis corretamente independente do diretório de trabalho.

---

### ADJ-02 — Corrigir `special_ad_categories` na criação de campanha
**Prioridade:** Alta | **Status:** Pendente
**Arquivo:** `server.py:173`

```python
# ANTES
"special_ad_categories": "[]",

# DEPOIS — omitir o campo (default da API é lista vazia)
# ou passar como string separada por vírgula se necessário:
# "special_ad_categories[]": ""
```

A maneira mais segura é omitir o campo para campanhas sem categoria especial
(crédito, habitação, emprego). A API assume lista vazia por padrão.

**Critério de aceitação:** `criar_campanha_pausada` retorna `{"id": "..."}` sem erro de validação.

---

### ADJ-03 — Declarar `starlette` no `requirements.txt`
**Prioridade:** Média | **Status:** Pendente
**Arquivo:** `requirements.txt`

```
starlette>=0.40.0
```

**Critério de aceitação:** `pip install -r requirements.txt` em ambiente limpo instala starlette sem depender de resolução transitiva.

---

### ADJ-04 — Adicionar `runtime.txt` para Vercel
**Prioridade:** Alta | **Status:** Pendente
**Arquivo:** `runtime.txt` (novo, raiz do projeto)

```
python3.12
```

**Critério de aceitação:** Vercel build usa Python 3.12, compatível com fastmcp 3.4.5.

---

### ADJ-05 — Adicionar `builds` no `vercel.json`
**Prioridade:** Média | **Status:** Pendente
**Arquivo:** `vercel.json`

```json
{
  "builds": [
    {
      "src": "api/index.py",
      "use": "@vercel/python"
    }
  ],
  "rewrites": [
    { "source": "/(.*)", "destination": "/api/index" }
  ]
}
```

**Critério de aceitação:** `vercel deploy` usa `@vercel/python` explicitamente.

---

### ADJ-06 — Atualizar `.env.example`
**Prioridade:** Baixa | **Status:** Pendente
**Arquivo:** `.env.example`

```bash
# System User Token do Business Manager (permissoes: ads_read e ads_management)
META_ACCESS_TOKEN=EAAG<token completo aqui>

# ID do App Meta (em developers.facebook.com > seu app > Painel)
META_APP_ID=

# Client Secret do App Meta
META_CLIENT_ID=

# Opcional: versao da Graph API (default v26.0)
# META_GRAPH_VERSION=v26.0

# Obrigatorio quando publicado na Vercel.
# Gere com: python -c "import secrets; print(secrets.token_urlsafe(32))"
MCP_AUTH_TOKEN=<token gerado>
```

**Critério de aceitação:** Qualquer dev consegue clonar o repo e saber quais variáveis precisa preencher.

---

### ADJ-07 — Cadastrar secrets no Vercel
**Prioridade:** Alta | **Status:** Pendente
**Execução:** CLI ou Dashboard

```bash
vercel env add META_ACCESS_TOKEN production
# (colar o valor do .env.local)

vercel env add MCP_AUTH_TOKEN production
# (colar o valor do .env.local)
```

**Critério de aceitação:** `GET https://<projeto>.vercel.app/health` retorna `{"status": "ok"}` e `POST /mcp` sem token retorna `401`.

---

### ADJ-08 — Decidir sobre `META_APP_ID` e `META_CLIENT_ID`
**Prioridade:** Média | **Status:** Decisão pendente

**Opção A — Remover** (se não forem usar OAuth ou validação de token):
Deletar do `.env.local`, não adicionar ao `.env.example` nem ao Vercel.

**Opção B — Usar no código** (para validação ou debug de token):
Adicionar ao `server.py` e expor via tool ou usar em `_token()` para validação.

**Critério de aceitação:** Variáveis não ficam definidas sem propósito no ambiente.

---

## 4. Ordem de Execução Recomendada

```
[IMEDIATO — quebra funcional]
ADJ-01  Corrigir caminho load_dotenv
ADJ-02  Corrigir special_ad_categories
ADJ-04  Criar runtime.txt

[CURTO PRAZO — deploy]
ADJ-07  Cadastrar secrets no Vercel
ADJ-05  Adicionar builds no vercel.json
ADJ-03  Declarar starlette no requirements.txt

[QUALIDADE]
ADJ-06  Atualizar .env.example
ADJ-08  Decidir sobre META_APP_ID / META_CLIENT_ID
```

---

## 5. Checklist de Validação

### Local (stdio)
- [ ] `pip install -r requirements.txt` sem erros
- [ ] `python server.py` inicia sem `RuntimeError`
- [ ] Claude Code conecta via `python server.py` e lista as tools
- [ ] `listar_contas` retorna dados reais do Business Manager
- [ ] `listar_campanhas` retorna campanhas de uma conta `act_`
- [ ] `metricas` retorna dados de performance
- [ ] `criar_campanha_pausada` cria campanha com status `PAUSED`

### Vercel (HTTP)
- [ ] `vercel deploy` conclui sem erro de build
- [ ] `GET /health` → `{"status": "ok", "servidor": "meta-ads-mcp"}`
- [ ] `POST /mcp` sem header → `401 Unauthorized`
- [ ] `POST /mcp` com `Authorization: Bearer <MCP_AUTH_TOKEN>` → resposta MCP válida
- [ ] Claude Code conecta via URL remota com o header de auth

---

## 6. Variáveis de Ambiente — Mapa Completo

| Variável | Local (`.env.local`) | Vercel | Obrigatória | Usada em |
|---|---|---|---|---|
| `META_ACCESS_TOKEN` | ✓ | Pendente (ADJ-07) | Sim | `server.py:_token()` |
| `MCP_AUTH_TOKEN` | ✓ | Pendente (ADJ-07) | Sim (Vercel) | `server.py:_auth()` |
| `META_GRAPH_VERSION` | Comentado | Não necessário | Não | `server.py:26` |
| `META_APP_ID` | ✓ | Decisão ADJ-08 | Não definido | Nenhum lugar |
| `META_CLIENT_ID` | ✓ | Decisão ADJ-08 | Não definido | Nenhum lugar |

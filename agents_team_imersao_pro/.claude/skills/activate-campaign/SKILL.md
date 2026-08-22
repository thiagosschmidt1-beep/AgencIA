---
name: activate-campaign
description: 'Ativa (coloca no ar — GASTO REAL) uma campanha de tráfego Meta Ads já existente de QUALQUER cliente configurado, de forma 100% autônoma e headless. Recebe `client_slug=<slug> campaign_meta_id=<id>`, valida que a campanha pertence ao cliente e está PAUSED, dentro do teto de orçamento, ativa via MCP da Meta, persiste status=ACTIVE e operation_logs no Supabase. Disparada pela fila `agent_jobs` quando o operador confirma a ativação pelo Nexus. NÃO cria campanha — só ativa uma existente.'
argument-hint: "client_slug=brasdente campaign_meta_id=120246500174380505"
allowed-tools: Read, Bash, Write, mcp__meta-ads__listar_contas, mcp__meta-ads__listar_campanhas, mcp__meta-ads__mudar_status_campanha, mcp__supabase__execute_sql
---

# Skill: /activate-campaign

Ativa **uma campanha de tráfego já criada** (campanha + ad sets + ads, todos hoje
PAUSED) de **qualquer cliente configurado** — **a partir da ativação, a campanha vai ao ar
e passa a GASTAR DE VERDADE**. Esta skill é o par seguro da `create-traffic-campaign`
(que nunca ativa nada): aqui a ativação é o objetivo, sob limites duros.

> Disparada pelo runner Fly.io via a fila `agent_jobs` (`scripts/poll-agent-jobs.sh`),
> que só enfileira esta skill depois que o operador confirmou a ativação por voz no
> Nexus (confirmação em 2 turnos). Mesmo assim, **revalide tudo aqui** — este é o
> ator privilegiado; a confirmação de voz não substitui as checagens.

---

## 1. Modo de operação — AUTONOMIA TOTAL (leia primeiro)

Roda em **headless** (`claude -p`). Regras inegociáveis:

1. **NUNCA chame `AskUserQuestion`.** Em qualquer dúvida/erro, **decida sozinho** pelos
   limites abaixo, registre no manifest e siga; se não der para prosseguir com
   segurança, **aborte sem ativar** e grave o manifest com `verified:false`.
2. **Meta só via MCP da Meta. Persistência só via MCP do Supabase.**
3. **Limites duros (defesa em profundidade — abortam a ativação se violados):**
   - A campanha tem que **pertencer ao cliente** `client_slug` (linha em `campaigns`
     com `client_id` do slug). Se não achar a campanha do cliente → **aborte**.
   - A campanha tem que estar **PAUSED** agora. Se já estiver `ACTIVE` → não faça nada
     (idempotente, sucesso). Qualquer outro status → **aborte**.
   - **Orçamento diário ≤ `daily_budget_cap_cents` do cliente**. Se o daily budget
     exceder o teto → **aborte sem ativar**.
   - Ative **somente** a campanha indicada e as entidades-filhas. Nunca ative
     outra campanha, nem altere orçamento, segmentação, criativo ou qualquer outra coisa.

---

## 2. Resolução do cliente

**Passo 0 — Extrair argumentos de `$ARGUMENTS`:**
- `client_slug` (obrigatório): slug do cliente (ex: `brasdente`)
- `campaign_meta_id` (obrigatório): ID numérico da campanha a ativar

Se qualquer um estiver ausente ou `campaign_meta_id` não for numérico (`^[0-9]+$`)
→ aborte com manifest `verified:false`.

**Passo 1 — Lookup no Supabase:**
```sql
SELECT id, name, ad_account_id, daily_budget_cap_cents, currency
FROM public.clients
WHERE slug = '<client_slug>';
```
- Não encontrado → aborte com `verified:false, error:"cliente não encontrado"`.
- Guardar `client_id` (uuid), `ad_account_id`, `daily_budget_cap_cents`.
- Usar `act_<ad_account_id>` nas chamadas Meta.

---

## 3. Passo a passo

### Passo 0 — Setup
```bash
DATE=$(TZ=America/Sao_Paulo date +%F)
STAMP=$(TZ=America/Sao_Paulo date +%Y%m%d-%H%M)
TRY_DIR=tentativas-geracao-de-campanhas
mkdir -p "${TRY_DIR}"
```

### Passo 1 — Lookup e validação no Supabase
Resolver cliente (§2 acima), depois validar a campanha:
```sql
SELECT c.id            AS campaign_uuid,
       c.client_id,
       c.name,
       c.status,
       c.daily_budget_cents,
       c.meta_campaign_id
  FROM public.campaigns c
  JOIN public.clients cl ON cl.id = c.client_id
 WHERE cl.slug = '<client_slug>'
   AND c.meta_campaign_id = '<campaign_meta_id>';
```
- Sem linha → **aborte** (`error:"campanha não encontrada para <client_slug>"`).
- `status='ACTIVE'` → **nada a fazer**; manifest `verified:true, already_active:true`.
- `status` diferente de `PAUSED` → **aborte** (`error:"status inesperado: <status>"`).
- `daily_budget_cents > daily_budget_cap_cents` → **aborte** (`error:"orçamento acima do teto"`).

Enumerar entidades-filhas:
```sql
SELECT s.meta_ad_set_id, s.id AS ad_set_uuid
  FROM public.ad_sets s
 WHERE s.campaign_id = '<campaign_uuid>';

SELECT a.meta_ad_id, a.id AS ad_uuid
  FROM public.ads a
  JOIN public.ad_sets s ON s.id = a.ad_set_id
 WHERE s.campaign_id = '<campaign_uuid>';
```

### Passo 2 — Revalidar na Meta
- `mcp__meta-ads__listar_contas` → confirmar `act_<ad_account_id>` ativo.
- `mcp__meta-ads__listar_campanhas` (conta `act_<ad_account_id>`) → encontrar a campanha
  e confirmar `effective_status=PAUSED` e `daily_budget`. Se daily budget exceder
  `daily_budget_cap_cents` → **aborte sem ativar** (mesmo que Supabase diga ≤ cap).

### Passo 3 — Ativar (campanha → ad sets → ads)
Uma campanha só entrega se campanha **e** ad sets **e** ads estiverem ACTIVE.
Ative de cima para baixo via `mcp__meta-ads__mudar_status_campanha`:
1. Campanha: `mudar_status_campanha` com `campaign_id=<campaign_meta_id>, status=ACTIVE`.
2. Cada `meta_ad_set_id` — status ACTIVE.
3. Cada `meta_ad_id` — status ACTIVE.

Se algum nível falhar, registre no manifest com estado parcial em `errors[]` e
em `operation_logs`, finalize com `verified:false`.

### Passo 4 — Validar
- `mcp__meta-ads__listar_campanhas` → confirmar campanha com `effective_status=ACTIVE`
  (ou `IN_PROCESS`/`PENDING_REVIEW`, que são normais logo após ativar). Documentar.

### Passo 5 — Persistir no Supabase
```sql
UPDATE public.campaigns SET status='ACTIVE' WHERE meta_campaign_id='<id>';
UPDATE public.ad_sets SET status='ACTIVE' WHERE campaign_id='<campaign_uuid>';
UPDATE public.ads SET status='ACTIVE'
  WHERE ad_set_id IN (SELECT id FROM public.ad_sets WHERE campaign_id='<campaign_uuid>');
```
**Uma linha por entidade** em `operation_logs`:
```sql
INSERT INTO public.operation_logs (client_id, entity_type, action, summary, actor)
VALUES ('<client_id>', 'campaign', 'activate',
        'Campanha <name> ativada — gasto real iniciado, R$<budget>/dia',
        'activate-campaign-skill');
```

### Passo 6 — Manifest da run
Escrever `${TRY_DIR}/${STAMP}-ativacao-<client_slug>.json`:
```json
{
  "skill": "activate-campaign",
  "client": "<client_slug>",
  "date": "<DATE>",
  "verified": true,
  "campaign_meta_id": "...",
  "campaign_name": "...",
  "daily_budget_cents": 5000,
  "activated": {"campaign": true, "ad_sets": ["..."], "ads": ["..."]},
  "already_active": false,
  "errors": [],
  "ads_manager_url": "https://business.facebook.com/adsmanager/manage/campaigns?act=<ad_account_id>"
}
```
Se abortou ou ativou parcialmente, `verified:false` + `errors[]` descritivo. **Sempre**
escreva o manifest — é o sinal que o runner inspeciona.

### Passo 7 — Resumo final (stdout)
Tabela campanha / ad sets / ads com IDs e `effective_status`, link do Ads Manager, e a
frase: **"Campanha ATIVA — gasto real iniciado."** (ou o motivo do abort).

---

## 4. Critério de sucesso
- Campanha indicada (e seus ad sets/ads) com `effective_status` ACTIVE na conta.
- `campaigns/ad_sets/ads.status='ACTIVE'` no Supabase + 1 `operation_logs action='activate'`
  por entidade.
- Manifest JSON gravado em `${TRY_DIR}/`.

## 5. Anti-padrões (NÃO faça)
- ❌ `AskUserQuestion` ou parar para pedir confirmação.
- ❌ Ativar campanha que não é do `client_slug` indicado.
- ❌ Ativar campanha com `status` ≠ PAUSED, ou com daily budget > teto do cliente.
- ❌ Mudar orçamento, segmentação, criativo, nome ou qualquer coisa além do status.
- ❌ Ativar outras campanhas além da indicada.
- ❌ Ativar entidades sem persistir status + `operation_logs` no Supabase.

## 6. Gotchas
- **Gasto real**: esta skill INICIA gasto. Os limites duros do §1.3 abortam em qualquer
  ambiguidade. Em dúvida, **não ative**.
- **Entrega no Brasil bloqueada** — workaround US→BR ativo (ver NOTES.md §10). A ativação
  não muda geo; se a Meta recusar entrega por verificação de anunciante, registre em
  `errors[]` e `verified:false`.
- **Headless** — sem `AskUserQuestion`. Confiamos nos limites duros deste markdown.

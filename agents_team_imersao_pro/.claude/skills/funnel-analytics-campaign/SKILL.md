---
name: funnel-analytics-campaign
description: 'Análise diária 100% autônoma e headless da performance de TODAS as campanhas ativas Meta Ads de UM cliente (qualquer objetivo) usando o connector mcp-meta-ads (read-only). Entrega o FUNIL DE CONVERSÃO COMPLETO (impression → link_click → landing_page_view → view_content → add_to_cart → initiate_checkout → purchase) com receita (action_values) e ROAS (purchase_roas). Diagnostica cruzando ≥2 métricas ancorado no north-star de cada objetivo. PERSISTE no Supabase: analyses + metric_snapshots + analysis_findings (ADR 0004) + funnel_events (ADR 0025). NÃO altera NADA na conta Meta. Use passando client_slug=<slug> como argumento.'
argument-hint: "client_slug=brasdente [window=last_7d] [compare=previous_period]"
allowed-tools: Read, Bash, Glob, Write, mcp__claude_ai_mcp-meta-ads__meta_token_status, mcp__claude_ai_mcp-meta-ads__list_ad_accounts, mcp__claude_ai_mcp-meta-ads__list_campaigns, mcp__claude_ai_mcp-meta-ads__list_adsets, mcp__claude_ai_mcp-meta-ads__list_ads, mcp__claude_ai_mcp-meta-ads__list_creatives, mcp__claude_ai_mcp-meta-ads__get_insights, mcp__claude_ai_mcp-meta-ads__run_insights_report, mcp__supabase__execute_sql, mcp__supabase__list_tables, mcp__plugin_telegram_telegram__reply
---

# Skill: /funnel-analytics-campaign

Avalia, **de ponta a ponta e sem intervenção humana**, a performance de **TODAS as campanhas
ativas** de **um cliente** no Meta Ads — qualquer objetivo. Usa o connector **`mcp-meta-ads`**
que entrega o **funil de conversão completo** com valores limpos.

> Runner Fly.io dispara 1×/dia às 08h BRT para cada cliente configurado no crontab.
> ADR: `docs/adr/0025-meta-ads-funnel-analytics.md`

---

## 1. Modo de operação — AUTONOMIA TOTAL

Roda em **headless** (`claude -p`). Regras inegociáveis:

1. **NUNCA chame `AskUserQuestion`.** Sem humano. Qualquer dúvida: decide sozinho, registra e segue.
2. **READ-ONLY na conta Meta.** Só lê. Nunca chame tools de escrita.
3. **Resolva erros por conta própria.** Se dado faltar, use fallbacks (§3) e registre no manifest. Só aborte se impossível ler qualquer dado — mesmo assim, grave `analyses` com `overall_verdict='error'`.
4. **Sempre grave a rodada.** Toda execução produz ≥1 linha em `analyses` + manifest.

---

## 2. Resolução do cliente

**Passo 0 — Identificar o slug:**

Leia `$ARGUMENTS` para extrair `client_slug` (ex: `client_slug=brasdente`).
Se `$ARGUMENTS` vazio → erro "client_slug obrigatório" e aborte gravando manifest com `verified:false`.

**Passo 1 — Lookup no Supabase:**
```sql
SELECT id, name, ad_account_id, daily_budget_cap_cents, currency
FROM public.clients
WHERE slug = '<client_slug>';
```
- Se não encontrado → aborte com manifest `verified:false, error:"cliente não encontrado"`.
- O `client_id` (uuid) é a chave para todas as gravações no banco.
- O `ad_account_id` é o ID sem prefixo `act_` — use `act_<ad_account_id>` nas chamadas Meta.

**Passo 2 — Confirmar conta Meta:**
Valide que a conta `act_<ad_account_id>` está acessível via `list_ad_accounts` ou `list_campaigns`.

---

## 3. Modelo de dados + framework de diagnóstico

### 3.1 Funil canônico (alimenta o funil visual no dashboard)

| step | event_type | fonte (campo/action) | fallback de action_type |
|---|---|---|---|
| 1 | `impression` | campo `impressions` | — |
| 2 | `link_click` | action `link_click` | — |
| 3 | `landing_page_view` | action `landing_page_view` | `omni_landing_page_view` |
| 4 | `view_content` | action `view_content` | `offsite_conversion.fb_pixel_view_content`, `omni_view_content` |
| 5 | `add_to_cart` | action `add_to_cart` | `offsite_conversion.fb_pixel_add_to_cart`, `omni_add_to_cart` |
| 6 | `initiate_checkout` | action `initiate_checkout` | `offsite_conversion.fb_pixel_initiate_checkout` |
| 7 | `purchase` | action `purchase` | `offsite_conversion.fb_pixel_purchase`, `omni_purchase` |

Por etapa: `count` = valor do action (inteiro, ausente ⇒ 0); `value_cents` = `action_values` × 100 (só `purchase` costuma ter valor).

### 3.2 North-star por objetivo

| Objetivo Meta | North-star | Métricas de suporte |
|---|---|---|
| `OUTCOME_TRAFFIC` / `LINK_CLICKS` | CPLPV (custo/landing_page_view) | CTR, frequência, CPM |
| `OUTCOME_LEADS` | CPL (custo/lead) | CTR, CPC, frequência |
| `OUTCOME_SALES` | ROAS (`purchase_roas`) + CPA | CTR, CPM, frequência |
| `OUTCOME_ENGAGEMENT` | Custo/conversa/mensagem | CTR, frequência, reach |
| `OUTCOME_AWARENESS` | CPM, reach, frequência | — |

**Regra diagnóstica**: cruze ≥2 métricas sempre. Nunca diagnóstico de métrica isolada.

### 3.3 Severidade dos findings

| Severidade | Critério |
|---|---|
| `critical` | North-star > 3× benchmark do setor OU orçamento completamente drenado sem resultado |
| `high` | North-star 2-3× benchmark OU frequência > 4 por 7d |
| `medium` | North-star 1.5-2× benchmark OU frequência 3-4 por 7d |
| `low` | Oportunidade de melhoria (não problema crítico) |

---

## 4. Passo a passo

### Passo 0 — Setup
```bash
DATE=$(TZ=America/Sao_Paulo date +%F)
STAMP=$(TZ=America/Sao_Paulo date +%Y%m%d-%H%M)
set -a && eval "$(tr -d '\r' < .env.local)" && set +a
```

### Passo 1 — Resolver cliente (ver §2 acima)

### Passo 2 — Coletar campanhas ativas
Use `list_campaigns` para `act_<ad_account_id>`, filtrando `effective_status=ACTIVE`.
Se nenhuma campanha ativa: grave `analyses` com `overall_verdict='no_data'` e finalize.

### Passo 3 — Coletar insights por nível
Para cada campanha ativa:
- **Nível campanha**: insights 7d (`date_preset=last_7`) com campos:
  `impressions, spend, clicks, ctr, cpc, cpm, frequency, reach, actions, action_values, cost_per_action_type, purchase_roas`
- **Nível ad set**: idem para cada ad set da campanha
- **Nível ad**: idem para cada ad (limit top 10 por gasto)

### Passo 4 — Construir funil canônico (§3.1)
Para cada entidade de campanha: extraia cada etapa do funil a partir de `actions[]` e `action_values[]`.

### Passo 4.5 — Carregar histórico de recomendações (últimos 30 dias)

Antes de diagnosticar, consulte o histórico de findings do cliente para evitar repetir recomendações já feitas e sem resultado:

```sql
SELECT
  af.metric_focus,
  af.recommended_action,
  af.recommendation_type,
  af.severity,
  COUNT(*)                          AS vezes_recomendado,
  MIN(a.window_stop)                AS primeira_vez,
  MAX(a.window_stop)                AS ultima_vez
FROM public.analysis_findings af
JOIN public.analyses a ON a.id = af.analysis_id
WHERE a.client_id = '<client_id>'
  AND a.window_stop >= now() - interval '30 days'
GROUP BY af.metric_focus, af.recommended_action, af.recommendation_type, af.severity
ORDER BY vezes_recomendado DESC;
```

Use o resultado para guiar o diagnóstico (Passo 5) com as seguintes regras:

**Regra 1 — Recomendação persistente sem melhora (≥3 semanas consecutivas):**
- Se a mesma `recommended_action` aparece ≥3 vezes nos últimos 30 dias E as métricas não melhoraram → **não repita** a mesma recomendação.
- Em vez disso, escale: sugira uma abordagem diferente (ex: se já recomendou "pausar criativo X" por 3 semanas, agora recomende "substituir audiência" ou "revisar oferta").
- Registre no finding: `"Recomendação anterior repetida X vezes sem resultado — nova abordagem sugerida"`.

**Regra 2 — Recomendação nova (nunca vista ou < 2 vezes):**
- Gere normalmente seguindo §3.2 + §3.3.

**Regra 3 — Problema resolvido:**
- Se uma recomendação anterior existia mas a métrica associada melhorou (comparando snapshot atual vs. anterior) → registre finding `low` com `"Melhora detectada em <metric_focus> — recomendação anterior possivelmente efetiva"`.

**Se não houver histórico** (primeiro run do cliente): ignore este passo e diagnostique normalmente.

### Passo 5 — Diagnosticar (§3.2 + §3.3)
- Identifique o north-star de cada campanha pelo `objective`
- Cruze ≥2 métricas por finding
- Classifique severidade (§3.3)
- Aplique as regras do histórico (§4.5) antes de formular cada `recommended_action`
- Gere `recommended_action` concreto (pausa, ajuste orçamento, novo criativo, etc.)
- Derive `overall_verdict`: `excellent` | `good` | `attention` | `critical` | `no_data` | `error`

### Passo 6 — Persistir no Supabase (via MCP `execute_sql`)

**6.1 — `analyses`:**
```sql
INSERT INTO public.analyses (client_id, overall_verdict, summary, window_start, window_stop)
VALUES ('<client_id>', '<verdict>', '<summary>', '<date-7d>', '<date-hoje>')
RETURNING id;
```

**6.2 — `metric_snapshots`** (1 linha por entidade):
```sql
INSERT INTO public.metric_snapshots
  (analysis_id, level, entity_name, entity_meta_id,
   impressions, spend_cents, ctr, cpc_cents, cpm_cents, cplpv_cents, frequency,
   link_clicks, landing_page_views)
VALUES ...
```

**6.3 — `analysis_findings`** (1 linha por finding):
```sql
INSERT INTO public.analysis_findings
  (analysis_id, severity, metric_focus, diagnosis, recommended_action,
   recommendation_type, confidence, entity_name)
VALUES ...
```

**6.4 — `funnel_events`** (upsert por campanha+etapa, janela 7d):
```sql
INSERT INTO public.funnel_events
  (client_id, campaign_meta_id, campaign_name, event_type, step_order,
   count, value_cents, window_days, snapshot_date)
VALUES ...
ON CONFLICT (client_id, campaign_meta_id, event_type, snapshot_date)
DO UPDATE SET count = EXCLUDED.count, value_cents = EXCLUDED.value_cents, updated_at = now();
```

**6.5 — `operation_logs`:**
```sql
INSERT INTO public.operation_logs (client_id, entity_type, action, summary, actor)
VALUES ('<client_id>', 'analysis', 'analyze', '<resumo>', 'funnel-analytics-skill');
```

### Passo 7 — Notificação Telegram (opcional)
Se `TELEGRAM_CHAT_ID` presente no env:
- Envie resumo: cliente, verdict, north-star do período, top finding, data.
- Falha no Telegram NÃO aborta a skill (telemetria degradável).

### Passo 8 — Manifest
Grave `/app/tentativas-geracao-de-campanhas/<STAMP>-analytics-<client_slug>.json`:
```json
{
  "skill": "funnel-analytics-campaign",
  "client": "<client_slug>",
  "analysis_id": "<uuid>",
  "overall_verdict": "<verdict>",
  "campaigns_analyzed": <n>,
  "findings_count": <n>,
  "verified": true,
  "errors": []
}
```

---

## 5. Gotchas conhecidos

| Sintoma | Fix |
|---|---|
| `actions` ausente no insight | Campo zerado no período — use `0` |
| `purchase_roas` ausente | Pixel não configurado; finding `medium` + `metric_focus='tracking'` |
| Campanha com `ACTIVE` mas sem gasto | Período insuficiente; inclua no funil com `impression=0` |
| Timeout na coleta de muitos ads | Limite a top-10 por gasto por ad set |
| Token sem `ads_read` | Erro 200 OAuthException; grave `analyses` com `overall_verdict='error'` |

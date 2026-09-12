---
name: optimize-campaign
description: 'Análise e aplicação de otimizações 100% autônoma e headless para UM cliente Meta Ads. Consulta o banco de otimizações fracassadas (failed_optimizations) antes de cada sugestão para nunca repetir erros conhecidos. Apresenta sugestões priorizadas via agent_jobs (aprovação do operador no Nexus) e aplica as aprovadas via MCP da Meta. Registra otimizações fracassadas novas no banco. Use passando client_slug=<slug> como argumento.'
argument-hint: "client_slug=brasdente [mode=suggest|apply] [job_id=<uuid>]"
allowed-tools: Read, Bash, Glob, Write, mcp__claude_ai_mcp-meta-ads__meta_token_status, mcp__claude_ai_mcp-meta-ads__list_ad_accounts, mcp__claude_ai_mcp-meta-ads__list_campaigns, mcp__claude_ai_mcp-meta-ads__list_adsets, mcp__claude_ai_mcp-meta-ads__list_ads, mcp__claude_ai_mcp-meta-ads__get_insights, mcp__claude_ai_mcp-meta-ads__update_campaign, mcp__claude_ai_mcp-meta-ads__update_adset, mcp__claude_ai_mcp-meta-ads__update_ad, mcp__supabase__execute_sql, mcp__supabase__list_tables
---

# Skill: /optimize-campaign

Avalia performance, consulta histórico de falhas e — **somente se aprovado pelo operador** —
aplica otimizações nas campanhas Meta Ads de um cliente, com autonomia total.

> Disparada via fila `agent_jobs` (kind=`optimize`) pelo Nexus após confirmação do operador.
> Regra inegociável: **nunca aplica sem `approved_suggestions` no job payload**.

---

## 1. Modo de operação — AUTONOMIA TOTAL

Roda em **headless** (`claude -p`). Regras:

1. **NUNCA chame `AskUserQuestion`.** Sem humano. Decida sozinho, registre e siga.
2. **Consulte o banco de falhas ANTES de qualquer sugestão.** Se a otimização já falhou antes para este cliente, descarte-a e passe para a próxima.
3. **Nunca aplique sem `approved_suggestions` no payload do job.** No modo `suggest`, só gera sugestões e encerra — não toca na conta Meta.
4. **Registe toda otimização aplicada** em `operation_logs`. Se depois a otimização provar ter sido ruim, o operador pode adicioná-la ao banco de falhas via Nexus.
5. **Sempre grave o manifest.** Toda execução produz ≥1 arquivo JSON em `/app/tentativas-otimizacao/<client_slug>-<timestamp>.json`.

---

## 2. Resolução do cliente e modo

**Passo 0 — Extrair argumentos de `$ARGUMENTS` e variáveis de ambiente:**
- `client_slug` (obrigatório) — ex: `client_slug=brasdente`
- `mode` (opcional, default: `suggest`) — `suggest` gera sugestões | `apply` aplica as aprovadas
- `job_id` — primeiro tente extrair de `$ARGUMENTS`; se ausente, use a variável de ambiente `$AGENT_JOB_ID` (sempre disponível quando disparado pela fila). Exemplo de extração via Bash:
  ```bash
  echo "$AGENT_JOB_ID"
  ```
  **O `job_id` é obrigatório para salvar sugestões no banco (modo suggest) e para ler sugestões aprovadas (modo apply). Sempre resolva antes de continuar.**

**Passo 1 — Lookup no Supabase:**
```sql
SELECT id, name, ad_account_id, daily_budget_cap_cents, currency, default_landing_url
FROM public.clients
WHERE slug = '<client_slug>';
```
- Se não encontrado → aborte com manifest `error: "cliente não encontrado"`.

---

## 3. Modo SUGGEST — gerar sugestões

### 3.1 Buscar dados de performance (últimos 7 dias)

Use `get_insights` para a conta `act_<ad_account_id>` com:
- `level`: campaign, adset, ad
- `date_preset`: last_7d
- `fields`: spend, impressions, reach, frequency, clicks, ctr, cpm, cpc, actions, action_values, purchase_roas

### 3.2 Identificar oportunidades

Avalie cada entidade usando estas regras (adapte ao north-star do cliente — ROAS para e-commerce, CPL para leads, custo/1k alcance para awareness):

**PAUSAR (risco imediato):**
- ROAS < 1x por 3+ dias com gasto relevante (> R$ 30 no período)
- Zero conversões em 7 dias com gasto > 2x o CPA meta do cliente
- CTR < 0,5% em criativo de formulário/tráfego

**ESCALAR (potencial de crescimento):**
- ROAS > 3x por 3+ dias consecutivos E gasto atual < 70% do cap diário do cliente
- Aumento máximo permitido: +20% do orçamento por vez
- Aguardar 48h entre aumentos (checar `operation_logs` para ver último aumento)

**TROCAR CRIATIVO (fadiga):**
- Frequência > 3 com CTR caindo semana a semana
- CPM subindo > 30% sem justificativa de sazonalidade

**REDISTRIBUIR ORÇAMENTO:**
- Concentrar 70% do orçamento nos 20% de campanhas/adsets com melhor performance

### 3.3 Consultar banco de falhas

Para CADA sugestão gerada, execute:

```sql
SELECT id, tipo_otimizacao, padrao, acao_tomada, por_que_nao_deu_certo, recomendacao
FROM public.failed_optimizations
WHERE client_slug = '<client_slug>'
  AND (
    padrao = '<padrao_da_sugestao>'
    OR entidade->>'campaign_id' = '<campaign_id>'
    OR entidade->>'adset_id' = '<adset_id>'
  )
ORDER BY created_at DESC
LIMIT 5;
```

**Se a consulta retornar resultados:**
- Verifique se a sugestão atual é a mesma ação que já falhou (mesmo padrão + mesma entidade).
- Se for idêntica → **descarte a sugestão** e registre no manifest: `{ "descartada": true, "motivo": "já tentada e falhou", "referencia": "<id-do-registro>" }`.
- Se for parecida mas não idêntica (ex: mesma campanha, ação diferente) → **inclua o aviso** na sugestão: `"atenção: ação similar já falhou nesta entidade — ver <id-do-registro>"`.

### 3.4 Montar lista de sugestões priorizadas

Gere um array JSON com no máximo 5 sugestões, ordenadas por impacto estimado (decrescente):

```json
[
  {
    "rank": 1,
    "acao": "pausar",
    "entidade_tipo": "campaign|adset|ad",
    "entidade_id": "<meta_id>",
    "entidade_nome": "<nome legível>",
    "motivo": "<diagnóstico em 1-2 frases com métricas concretas>",
    "impacto_estimado": "<economia ou ganho estimado>",
    "risco": "baixo|medio|alto",
    "historico_falhas": null
  }
]
```

### 3.5 Salvar sugestões no job e encerrar

**Atualize o job no Supabase** com as sugestões (modo suggest não aplica nada):

```sql
UPDATE public.agent_jobs
SET
  result = jsonb_build_object(
    'suggestions', '<array_json>',
    'generated_at', now()::text,
    'client_slug', '<client_slug>',
    'account_id', '<account_id>'
  ),
  status = 'done'
WHERE id = '<job_id>';
```

Se não há `job_id` mesmo após verificar `$AGENT_JOB_ID` (rodada manual sem fila), grave só o manifest local e encerre. Quando rodado via fila, `$AGENT_JOB_ID` **sempre** estará presente — use-o obrigatoriamente.

---

## 4. Modo APPLY — aplicar sugestões aprovadas

### 4.1 Ler sugestões aprovadas do job

```sql
SELECT payload, result
FROM public.agent_jobs
WHERE id = '<job_id>' AND kind = 'optimize' AND status IN ('running', 'pending');
```

Extraia `payload->>'approved_suggestions'` — array de `entidade_id`s aprovados pelo operador.

Se `approved_suggestions` estiver vazio ou ausente → **aborte**. Não aplique nada sem aprovação.

### 4.2 Aplicar cada sugestão aprovada

Para cada sugestão aprovada, execute a ação correspondente via MCP da Meta:

**Pausar campanha:**
```
update_campaign(campaign_id=<id>, status="PAUSED")
```

**Pausar adset:**
```
update_adset(adset_id=<id>, status="PAUSED")
```

**Pausar ad:**
```
update_ad(ad_id=<id>, status="PAUSED")
```

**Escalar orçamento de campanha (+20%):**
```
update_campaign(campaign_id=<id>, daily_budget=<budget_atual * 1.20>)
```

**Escalar orçamento de adset (+20%):**
```
update_adset(adset_id=<id>, daily_budget=<budget_atual * 1.20>)
```

**Regra de segurança obrigatória:** antes de qualquer aumento de orçamento, verifique:
```sql
SELECT daily_budget_cap_cents FROM public.clients WHERE slug = '<client_slug>';
```
O orçamento final não pode ultrapassar `daily_budget_cap_cents / 100` reais/dia por campanha.

### 4.3 Registrar em operation_logs

Para cada ação executada com sucesso:

```sql
INSERT INTO public.operation_logs
  (client_id, operation_type, entity_type, entity_id, details, status)
VALUES (
  '<client_uuid>',
  'optimize',
  '<campaign|adset|ad>',
  '<meta_entity_id>',
  jsonb_build_object(
    'acao', '<acao>',
    'motivo', '<motivo>',
    'job_id', '<job_id>',
    'valor_antes', '<valor_antes>',
    'valor_depois', '<valor_depois>'
  ),
  'success'
);
```

### 4.4 Finalizar o job

```sql
UPDATE public.agent_jobs
SET
  status = 'done',
  result = jsonb_build_object(
    'applied', '<lista_de_acoes_aplicadas>',
    'failed', '<lista_de_erros>',
    'completed_at', now()::text
  )
WHERE id = '<job_id>';
```

---

## 5. Registrar nova otimização fracassada

O operador pode instruir o Nexus a registrar uma otimização como fracassada após observar
resultados ruins. O Nexus usa a tool `record_failed_optimization` que gera um job `kind=record_failure`.

Quando a skill recebe `mode=record_failure`, insere em `failed_optimizations`:

```sql
INSERT INTO public.failed_optimizations
  (id, client_slug, account_id, data_acao, tipo_otimizacao, padrao, severidade,
   status_atual, entidade, acao_tomada, por_que_nao_deu_certo, recomendacao, custo_do_aprendizado)
VALUES (
  '<PREFIX>-<ANO>-<NNN>',  -- gere o próximo ID sequencial consultando o banco
  '<client_slug>',
  '<account_id>',
  '<data>',
  '<tipo>',
  '<padrao>',
  '<severidade>',
  '<status>',
  '<entidade_jsonb>',
  '<acao_tomada>',
  '<por_que_nao_deu_certo>',
  '<recomendacao>',
  '<custo_do_aprendizado>'
)
ON CONFLICT (id) DO UPDATE SET
  status_atual = EXCLUDED.status_atual,
  por_que_nao_deu_certo = EXCLUDED.por_que_nao_deu_certo,
  recomendacao = EXCLUDED.recomendacao,
  updated_at = now();
```

**Para gerar o próximo ID:**
```sql
SELECT id FROM public.failed_optimizations
WHERE client_slug = '<client_slug>'
ORDER BY id DESC LIMIT 1;
```
Incremente o número sequencial (ex: LUL-2026-003 → LUL-2026-004).

---

## 6. Manifest (sempre gravar)

```json
{
  "skill": "optimize-campaign",
  "client_slug": "<slug>",
  "account_id": "<account_id>",
  "mode": "suggest|apply|record_failure",
  "job_id": "<uuid ou null>",
  "timestamp": "<ISO>",
  "suggestions_generated": <N>,
  "suggestions_discarded_by_history": <N>,
  "actions_applied": ["<ação 1>", "..."],
  "errors": [],
  "verified": true
}
```

Salve em `/app/tentativas-otimizacao/<client_slug>-<timestamp>.json`.

---

## 7. O que esta skill NÃO faz

- ❌ Não cria campanhas novas (use `create-traffic-campaign`)
- ❌ Não muda objetivos de campanha ou targeting estrutural
- ❌ Não ativa campanhas PAUSED sem aprovação (use `activate-campaign`)
- ❌ Não altera criativos (imagem, texto, headline) — só pausa/ativa anúncios
- ❌ Não ultrapassa `daily_budget_cap_cents` do cliente em nenhuma hipótese

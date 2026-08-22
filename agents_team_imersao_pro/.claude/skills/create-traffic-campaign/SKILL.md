---
name: create-traffic-campaign
description: 'Cria de forma 100% autônoma e headless uma campanha Meta Ads para QUALQUER cliente configurado, adaptando objetivo, destino e criativo ao campaign_mode do cliente (TRAFFIC_WEBSITE, TRAFFIC_WHATSAPP, SALES_WEBSITE, LEADS_NATIVE, AWARENESS, MESSAGES). Campanha + adset + 3 ads sempre PAUSED. Aceita client_slug=<slug> como argumento obrigatório.'
argument-hint: "client_slug=brasdente [campaign_type=TRAFFIC_WHATSAPP] [whatsapp=5569840811139] [angle=vagas] [url=https://...] [budget-cents=5000] [n-creatives=3]"
allowed-tools: Read, Bash, Glob, Write, Agent, mcp__meta-ads__listar_contas, mcp__meta-ads__listar_campanhas, mcp__meta-ads__criar_campanha_pausada, mcp__supabase__execute_sql, mcp__supabase__list_tables
---

# Skill: /create-traffic-campaign

Cria, **de ponta a ponta e sem intervenção humana**, uma campanha no Meta Ads para
**qualquer cliente configurado**, adaptando objetivo, destino e formato de criativo ao
`campaign_mode` definido em `lista-de-clientes/SKILL.md`.

> Disparada 1×/dia pelo runner Fly.io (`crontab`) com `client_slug=<slug>`.

---

## 1. Modo de operação — AUTONOMIA TOTAL (leia primeiro)

Roda em **headless** (`claude -p`). Regras inegociáveis:

1. **NUNCA chame `AskUserQuestion`.** Em qualquer dúvida: **decida sozinho** com os
   defaults desta spec, registre no manifest e **siga em frente**.
2. **Resolva erros por conta própria.** Só aborte se impossível prosseguir sem gastar
   verba — e mesmo aí, **grave o manifest com `verified:false`** antes de sair.
3. **Meta só via MCP da Meta.** Persista tudo no Supabase via MCP.
4. **Limites duros:**
   - Orçamento ≤ `daily_budget_cap_cents` do cliente (padrão R$50). Nunca exceda.
   - **Tudo nasce PAUSED.** NUNCA chame `mudar_status_campanha` para ACTIVE.
   - Prefira reusar criativos já gerados hoje (respeita o cap LLM `WORKFLOW_LLM_BUDGET_USD_CAP=2.00`).

---

## 2. Resolução do cliente

**Passo 0 — Extrair `client_slug` de `$ARGUMENTS`:**
Se ausente → aborte com manifest `verified:false, error:"client_slug obrigatório"`.

**Passo 1 — Lookup no Supabase:**
```sql
SELECT id, name, ad_account_id, default_landing_url,
       daily_budget_cap_cents, currency, materials_path
FROM public.clients
WHERE slug = '<client_slug>';
```
- Não encontrado → aborte com `verified:false, error:"cliente não encontrado"`.
- Guardar `client_id`, `ad_account_id`, `daily_budget_cap_cents`.

**Passo 2 — Ler config do cliente em `lista-de-clientes/SKILL.md`:**
`Read` o arquivo `.claude/skills/lista-de-clientes/SKILL.md` e extraia:
- `campaign_mode` — define toda a lógica de campanha (ver §3)
- `Facebook Page` — `page_id`
- `Pixel` — `pixel_id` (pode ser "sem pixel")
- Campos mode-específicos: `Landing URL`, `WhatsApp`, `WhatsApp Link`, `Lead Form ID`

Se `campaign_mode` não encontrado → default `TRAFFIC_WEBSITE`.

**Passo 3 — Confirmar conta Meta:**
`mcp__meta-ads__listar_contas` → confirmar `act_<ad_account_id>` acessível.
Se não responder → gravar manifest `verified:false` com o erro e sair.

---

## 3. Modos de campanha

| Mode | Objetivo Meta | destination_type | optimization_goal | CTA | Pixel obrigatório |
|---|---|---|---|---|---|
| `TRAFFIC_WEBSITE` | `OUTCOME_TRAFFIC` | `WEBSITE` | `LANDING_PAGE_VIEWS` → fallback `LINK_CLICKS` | `LEARN_MORE` | não |
| `TRAFFIC_WHATSAPP` | `OUTCOME_TRAFFIC` | `WHATSAPP` | `LINK_CLICKS` | `WHATSAPP_MESSAGE` | não |
| `TRAFFIC_INSTAGRAM` | `OUTCOME_TRAFFIC` | `INSTAGRAM_PROFILE` | `LINK_CLICKS` | `LEARN_MORE` | não |
| `SALES_WEBSITE` | `OUTCOME_SALES` | `WEBSITE` | `OFFSITE_CONVERSIONS` | `SHOP_NOW` | sim |
| `LEADS_NATIVE` | `OUTCOME_LEADS` | `ON_AD` | `LEAD_GENERATION` | `SIGN_UP` | não |
| `AWARENESS` | `OUTCOME_AWARENESS` | — | `REACH` | `LEARN_MORE` | não |
| `MESSAGES` | `OUTCOME_ENGAGEMENT` | `MESSENGER` | `CONVERSATIONS` | `MESSAGE_PAGE` ou `WHATSAPP_MESSAGE` | não |

**Defaults gerais** (todos os modos):
- Buying type: `AUCTION`
- Budget mode: **CBO** (budget na campanha, não no ad set)
- Daily budget: `daily_budget_cap_cents` do cliente (clampado ao teto)
- Bid strategy: `LOWEST_COST_WITHOUT_CAP`
- Billing event: `IMPRESSIONS`
- Geo: `["US"]` (**BR bloqueado** — ver §8)
- Advantage+ Audience: `targeting_automation.advantage_audience: 1`
- Nº criativos: 3 — ângulos **autoridade / dor / oferta**
- Status final: **PAUSED** (campanha, ad set e todos os ads)

**Naming** (date em `America/Sao_Paulo`, `DATE=YYYY-MM-DD`):
- Campanha: `[<MODE_TAG>][<CLIENT_SLUG_UPPER>][${DATE}] <Descrição> — US`
- Ad set: `[<MODE_TAG>][<CLIENT_SLUG_UPPER>] adset — US — Advantage+ — <OPT_GOAL> — ${DATE}`
- Ads: `[<MODE_TAG>][<CLIENT_SLUG_UPPER>] v1 Autoridade — ${DATE}` / `v2 Dor` / `v3 Oferta`

Tags por modo: `TRF`=TRAFFIC_WEBSITE, `WA`=TRAFFIC_WHATSAPP, `VND`=SALES_WEBSITE,
`LEAD`=LEADS_NATIVE, `AWR`=AWARENESS, `MSG`=MESSAGES.

**Overrides via `$ARGUMENTS`:**
- `campaign_type` — sobrepõe o `campaign_mode` do cliente (útil para clientes multi-modo como Piemon)
- `whatsapp` — sobrepõe o WhatsApp do cliente (útil para Piemon: número diferente por campanha)
- `angle` — hint de ângulo de copy (`vagas`, `ofertas`, etc.) para clientes com múltiplos WhatsApps
- `url`, `budget-cents` (clamp ao teto), `n-creatives`

---

## 4. Passo a passo

### Passo 0 — Setup
```bash
DATE=$(TZ=America/Sao_Paulo date +%F)
STAMP=$(TZ=America/Sao_Paulo date +%Y%m%d-%H%M)
set -a && eval "$(tr -d '\r' < .env.local)" && set +a
ADS_DIR=".claude/materiais-das-empresas/<client_slug>/generated-ads/${DATE}"
TRY_DIR=tentativas-geracao-de-campanhas
mkdir -p "${ADS_DIR}" "${TRY_DIR}"
```
Parse `$ARGUMENTS`; aplicar defaults do §3; **clampar budget ao teto**.

### Passo 1 — Resolver cliente (§2)

### Passo 2 — Gerar criativos

**Idempotência (só para o dia de hoje):** se `${ADS_DIR}` já tem os 3 PNGs e
`public-urls.txt` → **reuse** as URLs e pule para o Passo 3.

Senão, execute a cadeia por modo:

#### Modos TRAFFIC_WEBSITE e SALES_WEBSITE (têm landing URL)
1. `Agent(subagent_type="scrape-extractor")` com a `Landing URL` → `scrape.json`.
2. Para cada ângulo (`autoridade`, `dor`, `oferta`):
   - `Agent(subagent_type="copywriter")` com `{scrape, objective:"<META_OBJECTIVE>",
     configHints:{brandName:"<name>", angle:<ângulo>}}` → headline (≤40), primaryText (≤250),
     description (≤30), callToActionType (force o CTA do modo).
   - `Agent(subagent_type="image-prompt-generator")` com scrape + refs visuais → `prompt`.
   - `Skill(skill="image-generate", ...)` → PNG 1024×1024. Gate visual (máx 3 tentativas).
3. Upload para bucket público `ad-ingest` → `public-urls.txt` (confirmar `200`).

#### Modos TRAFFIC_WHATSAPP, MESSAGES, AWARENESS, LEADS_NATIVE (sem landing URL)
> Sem URL para scrape — usar materiais da marca como base do brief.

1. `Read` os arquivos em `.claude/materiais-das-empresas/<client_slug>/` (logo, foto, exemplos de ads).
2. Montar `brief` manual com: nome do cliente, objetivo do modo, ângulo, materiais disponíveis.
3. Para cada ângulo:
   - `Agent(subagent_type="copywriter")` com `{brief, objective:"<META_OBJECTIVE>",
     configHints:{brandName:"<name>", angle:<ângulo>}}` → copy adaptada ao modo:
     - `MESSAGES`/`TRAFFIC_WHATSAPP`: copy focada em "fale conosco / entre no grupo"
     - `AWARENESS`: copy de reconhecimento de marca, sem CTA de resposta direta
     - `LEADS_NATIVE`: copy focada em "cadastre-se / saiba mais", sem mencionar "site"
   - `Agent(subagent_type="image-prompt-generator")` com brief + refs → `prompt`.
   - `Skill(skill="image-generate", ...)` → PNG 1024×1024. Gate visual (máx 3 tentativas).
4. Upload para `ad-ingest` → `public-urls.txt`.

### Passo 3 — Criar campanha (PAUSED)
`mcp__meta-ads__criar_campanha_pausada`:
- `account_id=act_<ad_account_id>`
- `name=[<MODE_TAG>][<CLIENT_SLUG_UPPER>][${DATE}] <descrição> — US`
- `objective=<META_OBJECTIVE do modo>`, `buying_type=AUCTION`, `special_ad_categories=[]`
- `status=PAUSED`, `daily_budget=<daily_budget_cap_cents>`, `bid_strategy=LOWEST_COST_WITHOUT_CAP`
- Guardar `meta_campaign_id`.

### Passo 4 — Criar ad set (PAUSED)

**Configuração base (todos os modos):**
- `status=PAUSED`, sem budget (CBO)
- `targeting={"geo_locations":{"countries":["US"]},"targeting_automation":{"advantage_audience":1}}`
- Se erro subcode `3858634` → manter `["US"]` (§8).

**Por modo:**

**TRAFFIC_WEBSITE:**
- `optimization_goal=LANDING_PAGE_VIEWS`, `billing_event=IMPRESSIONS`, `destination_type=WEBSITE`
- Se Meta recusar `LANDING_PAGE_VIEWS` → recriar com `optimization_goal=LINK_CLICKS`

**TRAFFIC_WHATSAPP:**
- `optimization_goal=LINK_CLICKS`, `billing_event=IMPRESSIONS`, `destination_type=WHATSAPP`
- Ou `destination_type=WEBSITE` com link `wa.me` se `WHATSAPP` não aceito

**TRAFFIC_INSTAGRAM:**
- `optimization_goal=LINK_CLICKS`, `billing_event=IMPRESSIONS`, `destination_type=INSTAGRAM_PROFILE`
- Se `INSTAGRAM_PROFILE` rejeitado → `destination_type=WEBSITE` com link do perfil do Instagram

**SALES_WEBSITE:**
- `optimization_goal=OFFSITE_CONVERSIONS`, `billing_event=IMPRESSIONS`, `destination_type=WEBSITE`
- `promoted_object={"pixel_id":"<pixel_id>","custom_event_type":"PURCHASE"}`
- Se pixel rejeitado → fallback `optimization_goal=LINK_CLICKS` sem `promoted_object`

**LEADS_NATIVE:**
- `optimization_goal=LEAD_GENERATION`, `billing_event=IMPRESSIONS`, `destination_type=ON_AD`
- Se `ON_AD` rejeitado → `destination_type=UNDEFINED`

**AWARENESS:**
- `optimization_goal=REACH`, `billing_event=IMPRESSIONS`
- Sem `destination_type`

**MESSAGES:**
- `optimization_goal=CONVERSATIONS`, `billing_event=IMPRESSIONS`, `destination_type=MESSENGER`
- Ou `destination_type=WHATSAPP` se cliente tiver `WhatsApp` preenchido

Guardar `meta_ad_set_id`.

### Passo 5 — Criar os 3 ads (PAUSED)

**Estrutura base do criativo (todos os modos):**
A imagem vai DENTRO de `link_data.picture` (URL pública). NUNCA ponha `image_url` no topo.

**TRAFFIC_WEBSITE / SALES_WEBSITE:**
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "<Landing URL>",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "description": "<description>",
      "call_to_action": {"type": "LEARN_MORE"}
    }
  }
}
```
SALES_WEBSITE: trocar CTA por `SHOP_NOW`.

**TRAFFIC_WHATSAPP:**
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "https://wa.me/<whatsapp>",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "call_to_action": {"type": "WHATSAPP_MESSAGE"}
    }
  }
}
```
Usar o `whatsapp` de `$ARGUMENTS` se presente; senão o `WhatsApp` do cliente em lista-de-clientes.

**TRAFFIC_INSTAGRAM:**
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "https://www.instagram.com/<instagram_handle>/",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "call_to_action": {"type": "LEARN_MORE"}
    }
  }
}
```
Se o cliente tiver `Instagram ID` configurado, usar também `instagram_actor_id: "<instagram_id>"` no
`object_story_spec` para vincular o criativo à conta do Instagram diretamente.
Copy deve ter ângulo de "siga nosso Instagram / veja mais conteúdo".

**MESSAGES:**
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "https://www.facebook.com/<page_id>",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "call_to_action": {"type": "MESSAGE_PAGE"}
    }
  }
}
```
Se cliente tiver `WhatsApp` preenchido → substituir `link` por `https://wa.me/<whatsapp>` e CTA por `WHATSAPP_MESSAGE`.

**LEADS_NATIVE:**
Se `Lead Form ID` for um número (já resolvido) → usar diretamente.
Se `Lead Form ID` contiver "buscar em runtime" → chamar via MCP Meta o endpoint
`/act_<ad_account_id>/leadgen_forms?fields=id,name&limit=100`, filtrar pelo `Lead Form Name`
e usar o `id` retornado. Se não encontrar → alertar no manifest e usar link da página como fallback.

Se `Lead Form ID` preenchido (número):
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "https://www.facebook.com/<lead_form_id>",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "call_to_action": {"type": "SIGN_UP", "value": {"lead_gen_form_id": "<lead_form_id>"}}
    }
  }
}
```
Se `Lead Form ID` não preenchido (placeholder) → logar decisão no manifest:
`"lead_form_id não configurado — ads criados sem formulário, configurar manualmente no Ads Manager"`.
Usar `link` = `https://www.facebook.com/<page_id>` como fallback e CTA `SIGN_UP`.

**AWARENESS:**
```json
{
  "object_story_spec": {
    "page_id": "<page_id>",
    "link_data": {
      "link": "https://www.facebook.com/<page_id>",
      "picture": "<public_image_url>",
      "message": "<primaryText>",
      "name": "<headline>",
      "call_to_action": {"type": "LEARN_MORE"}
    }
  }
}
```

Guardar cada `meta_ad_id`.

### Passo 6 — Validar
- `mcp__meta-ads__listar_campanhas` → confirmar `status=PAUSED`.
- Criativo em `IN_PROCESS` é **normal** (Meta ingerindo a imagem) — não é erro.
- Ad sem imagem → recriar com `picture` dentro de `link_data`.

### Passo 7 — Persistir no Supabase
Via `mcp__supabase__execute_sql`, upserts com `ON CONFLICT DO UPDATE`:
```sql
-- campaigns, ad_sets, generated_images, creatives, ads, operation_logs
-- (estrutura idêntica ao schema existente — ver migration 20260530000001)
INSERT INTO public.campaigns (client_id, meta_campaign_id, name, objective, ...)
  VALUES (...) ON CONFLICT (meta_campaign_id) DO UPDATE SET ...;
-- repetir para ad_sets, creatives, ads
INSERT INTO public.operation_logs (client_id, entity_type, action, summary, actor)
  VALUES ('<client_id>', 'campaign', 'create',
    'Campanha <MODE> R$<budget>/dia (US) criada PAUSED', 'create-traffic-campaign-skill');
```

### Passo 8 — Manifest da run
Escrever `${TRY_DIR}/${STAMP}-<MODE>-<client_slug>.json`:
```json
{
  "skill": "create-traffic-campaign",
  "client": "<client_slug>",
  "campaign_mode": "<MODE>",
  "date": "<DATE>",
  "verified": true,
  "campaign": {"meta_campaign_id": "...", "name": "...", "status": "PAUSED", "daily_budget_cents": 5000},
  "ad_set": {"meta_ad_set_id": "...", "optimization_goal": "...", "geo": ["US"]},
  "ads": [{"meta_ad_id": "...", "angle": "autoridade", "image_url": "...", "status": "PAUSED"}],
  "creatives_source": "generated",
  "errors": [],
  "decisions": ["geo=US (BR bloqueado, subcode 3858634)", "cta=<CTA>", "..."],
  "ads_manager_url": "https://business.facebook.com/adsmanager/manage/campaigns?act=<ad_account_id>"
}
```
Se algo falhou: `verified:false` + `errors[]`. **Sempre** escreva o manifest.

### Passo 9 — Resumo final (stdout)
Tabela com campanha / ad set / 3 ads (IDs, status), modo usado, link do Ads Manager.
Frase final: **"Tudo PAUSED — custo Meta = 0. Ative manualmente quando aprovar."**
Para `LEADS_NATIVE` sem form ID: alertar que formulário precisa ser associado manualmente.

---

## 5. Critério de sucesso
- 3 PNGs em `${ADS_DIR}` + `public-urls.txt` (URLs `200`).
- 1 campanha + 1 ad set + 3 ads **PAUSED** na conta do cliente.
- Linhas no Supabase + 1 `operation_logs` por entidade.
- Manifest JSON gravado em `${TRY_DIR}/`.

---

## 6. Anti-padrões (NÃO faça)
- ❌ `AskUserQuestion` ou parar para pedir confirmação.
- ❌ Chamar `mudar_status_campanha` com `status=ACTIVE`.
- ❌ Orçamento > `daily_budget_cap_cents` do cliente.
- ❌ `image_url` no topo do creative (ad sai sem imagem).
- ❌ Targeting `["BR"]` (trava — subcode 3858634).
- ❌ Signed URL privada do bucket `creatives` (Meta não baixa — subcode 3858258).
- ❌ Criar entidades na Meta sem persistir no Supabase + `operation_logs`.
- ❌ Regerar imagem se já existe a pasta do dia (desperdício de custo).
- ❌ Usar `OUTCOME_TRAFFIC` para clientes com `SALES_WEBSITE` ou `LEADS_NATIVE`.

---

## 7. Campos obrigatórios por modo (checklist antes de criar)

| Mode | Campo obrigatório | Fallback se ausente |
|---|---|---|
| `TRAFFIC_WEBSITE` | `Landing URL` | abortar com erro claro |
| `TRAFFIC_WHATSAPP` | `whatsapp` (arg ou campo do cliente) | usar link da página no Facebook |
| `TRAFFIC_INSTAGRAM` | `Instagram Handle` do cliente | usar link genérico da página Facebook |
| `SALES_WEBSITE` | `Landing URL` + `Pixel` | sem pixel: fallback LINK_CLICKS sem promoted_object |
| `LEADS_NATIVE` | `Lead Form ID` | criar ads com link da página; alertar no manifest |
| `AWARENESS` | nenhum | — |
| `MESSAGES` | `page_id` + `WhatsApp` | WhatsApp ausente: usar CTA `MESSAGE_PAGE` |

---

## 8. Gotchas obrigatórios (memória do projeto + ADRs)

**BR bloqueado** — `geo_locations.countries:["BR"]` falha com subcode `3858634`.
Usar sempre `["US"]` com sufixo no nome. Reavaliar após aprovação Meta.

**Imagem inline em `link_data.picture`** — única forma de anexar imagem com URL pública.
Pôr `image_url` no topo do creative cria ad sem imagem.

**Bucket público `ad-ingest`** — ADR 0003. Suba sempre para o bucket **público**.
Path: `<client_slug>/<data>/<rand-hex>/`.

**Headless** — sem `AskUserQuestion`. Toda decisão deve ser registrada no manifest.

---

## 9. Pré-requisitos
- `.env.local` na raiz com `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- MCP da Meta e MCP do Supabase autenticados (já feito no runner).
- Bucket público `ad-ingest` no Supabase.
- Cliente registrado em `public.clients` e em `.claude/skills/lista-de-clientes/SKILL.md`.

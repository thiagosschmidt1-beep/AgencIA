# NOTES.md — Agência de Agents Meta Ads (agents_team_imersao_pro)

> Arquivo vivo. Atualizar após cada sessão de implementação antes de compactar.
> Última atualização: 2026-08-29 (sessão 5 — parte 2)

---

## 🟡 RETOMAR AQUI — PRÓXIMA SESSÃO

**Pasta a abrir no VS Code:**
```
C:\Users\User\Desktop\Projetos IA\AgencI.A\agents_team_imersao_pro
```

**GitHub:** https://github.com/thiagosschmidt1-beep/AgencIA (conta: thiagosschmidt1-beep, branch: main)

**O que já está feito (não refazer):**
- 11 clientes ativos configurados com Page IDs, Pixels, campaign_mode, URLs e WhatsApps ✅
- 3 skills genéricas revisadas com branching por campaign_mode ✅
- Clientes removidos: firebull, popular, daniele-melo, dpo-board ✅
- GitHub: projeto `AgencIA` criado e código pushed ✅
- EasyPanel (DigitalOcean): runner `meta-ads-runner` deployado no projeto `agencia-ia` ✅
- Variáveis de ambiente corrigidas no EasyPanel (sessão 5) ✅
- Runner rodando: supercronic ativo, poll-agent-jobs.sh executando a cada minuto ✅
- Facebook Page IDs e default_landing_url populados no Supabase via SQL (sessão 5) ✅
- `funnel-analytics-campaign` aprimorado: consulta histórico de findings 30 dias antes de diagnosticar (commit `cb68256`) ✅
- Skill testada com sucesso: lulibaby analisada, dados persistidos no Supabase (sessão 5) ✅
- Modelo trocado para `claude-haiku-4-5-20251001` via env var `CLAUDE_MODEL` no EasyPanel ✅
- Schema do banco corrigido: `operation_logs` aceita `entity_type='analysis'` e `action='analyze'` ✅
- SKILL.md corrigido: `overall_verdict`, `funnel_events` e `operation_logs` alinhados com schema real ✅
- **Custo reduzido**: analytics semanal (segunda 08h) + guard de gasto ativo + criação só via Nexus ✅

**O que falta — em ordem:**

1. **⚠️ PENDENTE — Redeploy + reautenticar Claude após mudança de crontab**
   - Fazer redeploy no EasyPanel para pegar o novo crontab
   - Após redeploy: Console → bash → `claude` → autenticar MCPs → `/exit`

2. **Testar** via Nexus voice: "analise a performance da lulibaby"

**Contexto do runner (EasyPanel):**
- Projeto: `agencia-ia` → serviço: `meta-ads-runner`
- Console: EasyPanel → serviço → aba Console → bash
- Supabase MCP: ✅ conectado
- Meta Ads MCP: ✅ token correto (`META_ADS_MCP_TOKEN` configurado no EasyPanel)
- `entrypoint.sh`: configura MCP automaticamente ao iniciar
- URL Meta Ads MCP: `https://meta-ads-mcp-xi.vercel.app/mcp`
- ⚠️ Env vars EasyPanel: `ANTHROPIC_API_KEY` e `OPENAI_API_KEY` agora corretas (sessão 5 — estavam corrompidas por formatação errada)

**Problema recorrente — jq syntax error:**
- Aparece no início e fim de cada run mas não bloqueia a execução
- É cosmético — versão do `jq` no container não suporta a sintaxe usada no `emit-from-stream.py`
- Pode corrigir em sessão futura se necessário

---

---

## 1. Missão e visão geral

Agência de tráfego Meta Ads 100% operada por IAs, 24/7.
**Versão**: "entrada" — dashboard + chat de voz Nexus + agents no backend via fila.
**Capacidades**: criar campanha de tráfego · ativar campanha · análise de performance/funil.

---

## 2. Stack

| Camada | Tecnologia |
|---|---|
| Web dashboard | Next.js 15 (App Router) + React 19 + TypeScript 5.6 + Tailwind 4 |
| API | Hono num route handler catch-all (`/api/[[...route]]/route.ts`) |
| Auth | Senha única SHA-256 + cookie JWT (`jose`) |
| DB | Supabase Postgres — RLS deny-by-default; acesso via service key |
| Cache/Memória Nexus | Upstash Redis (free tier) |
| Voz Nexus | Whisper (OpenAI STT) + ElevenLabs TTS + VAD AudioWorklet |
| AI | Anthropic SDK — Nexus usa `claude-sonnet-4-6` (env `NEXUS_MODEL`) |
| MCP Meta | `meta-ads-mcp` (MCP da Meta — connector único para Marketing API) |
| Runner | Fly.io machine (region `gru`) + supercronic + Claude Code CLI |
| Deploy dashboard | Vercel (region `gru1`) |
| Deploy DB | Supabase (region `sa-east-1`) |

---

## 3. Arquitetura de fluxo

```
Operador (voz) → Nexus (dashboard) → agent_jobs (Supabase) → poll-agent-jobs.sh (Fly.io) → skill (claude -p) → Meta API + Supabase
```

- O Nexus NÃO toca a Meta diretamente — apenas enfileira jobs.
- O runner no Fly.io faz poll a cada minuto (`* * * * *`) e roda jobs via `run-skill.sh`.
- Skills rodam em headless (`claude -p --dangerously-skip-permissions`), sem interação humana.
- Confirmação de ativação é feita em 2 turnos no Nexus antes de enfileirar.

---

## 4. Estrutura de arquivos-chave

```
web/
  app/(app)/
    dashboard/page.tsx          — overview: clientes, campanhas, atividade recente
    dashboard/layout.tsx        — header + NexusWidget embutido
    dashboard/clients/[slug]/   — detalhe do cliente: performance, campanhas, criativos
    login/                      — auth
  app/api/[[...route]]/route.ts — API Hono: auth + nexus STT/chat/TTS
  lib/
    env.ts                      — env vars validadas (server-only)
    nexus/
      chat.ts                   — pipeline chat Nexus com Claude
      tools.ts                  — tools do Nexus + handlers (lista clientes, enfileira jobs)
      prompt.ts                 — system prompt do Nexus
      stt.ts / tts.ts           — Whisper + ElevenLabs
      memory.ts                 — memória persistente via Upstash Redis
      agent-trigger.ts          — enfileiramento de jobs
    auth/                       — password, session, turnstile
    services/
      dashboard.ts              — query de overview (clientes + atividade)
      client-detail.ts          — query de detalhe do cliente
  components/nexus/
    nexus-widget.tsx            — widget flutuante de voz
    use-nexus-voice.ts          — hook: VAD → STT → chat → TTS
    vad-mic.ts                  — captura de microfone
    nexus-visualizer.tsx        — visualização de áudio

.claude/skills/
  create-traffic-campaign/SKILL.md                  — GENÉRICA: cria campanha CBO + 3 ads PAUSED para qualquer cliente (client_slug=<slug>)
  activate-campaign/SKILL.md                        — GENÉRICA: ativa campanha (gasto real) para qualquer cliente
  funnel-analytics-campaign/SKILL.md                — GENÉRICA: análise funil + métricas para qualquer cliente
  create-traffic-cliente-exemplo-campaign/SKILL.md  — legado (template original — mantido para referência)
  activate-campaign-cliente-exemplo/SKILL.md        — legado (template original — mantido para referência)
  funnel-analytics-cliente-exemplo-campaign/SKILL.md — legado (template original — mantido para referência)
  lista-de-clientes/SKILL.md                        — IDs e dados de todos os 15 clientes reais + contas não identificadas
  lista-de-produtos/SKILL.md                        — catálogo de produtos e briefs

supabase/migrations/
  20260530000001_init_meta_ads_agency_schema.sql    — schema base (clients, campaigns, ad_sets, ads, creatives, operation_logs)
  20260530000002_add_meta_ads_performance_analysis.sql — analyses, metric_snapshots, analysis_findings
  20260530000003_seed_client_cliente_exemplo.sql    — seed do cliente template (mantido)
  20260530000006_add_agent_events.sql               — agent_events (telemetria)
  20260530000007_add_agent_jobs.sql                 — agent_jobs (fila) + claim_agent_job RPC
  20260614000001_add_funnel_events.sql              — funnel_events (read model funil visual)
  20260821000001_seed_real_clients.sql              — ✅ APLICADO: 15 clientes reais da agência

scripts/
  run-skill.sh         — wrapper que roda skill via `claude -p`, com timeout 1500s
  poll-agent-jobs.sh   — claims job da fila e executa (roda a cada minuto via cron)
  entrypoint.sh        — entrypoint do container Fly.io
  emit-from-stream.py  — captura NDJSON do claude -p e grava agent_events no Supabase

crontab (supercronic):
  08:00-08:14 BRT → funnel-analytics-campaign client_slug=<slug> (1 por minuto, 15 clientes)
  10:00-10:14 BRT → create-traffic-campaign client_slug=<slug> (1 por minuto, 15 clientes)
  */1 min   → poll-agent-jobs.sh (fila on-demand)
```

---

## 5. Variáveis de ambiente obrigatórias

### Dashboard (Vercel / `.env.local`)

| Variável | Descrição |
|---|---|
| `ANTHROPIC_API_KEY` ou `CLAUDE_API_KEY` | Chave Anthropic (Nexus chat) |
| `OPENAI_API_KEY` | Whisper STT + geração de imagens |
| `SUPABASE_URL` | URL pública do projeto Supabase |
| `SUPABASE_SECRET_KEY` | Service role key (bypassa RLS) |
| `NEXT_PUBLIC_SUPABASE_URL` | Mesmo valor (para o client browser) |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Anon key pública |
| `AUTH_SECRET` | Segredo JWT (mínimo 32 chars aleatórios) |
| `DASHBOARD_PASSWORD` | Hash SHA-256 da senha do operador |
| `ELEVENLABS_API_KEY` | ElevenLabs TTS |
| `ELEVENLABS_VOICE_ID` | ID da voz no ElevenLabs |
| `UPSTASH_REDIS_REST_URL` | Upstash Redis (memória Nexus) |
| `UPSTASH_REDIS_REST_TOKEN` | Upstash Redis token |
| `CLOUDFLARE_TURNSTILE_SITE_KEY` | (opcional) proteção bot no login |
| `CLOUDFLARE_TURNSTILE_SECRET_KEY` | (opcional) servidor Turnstile |

### Runner Fly.io (via `fly secrets set`)
Mesmas variáveis acima + secrets do MCP Meta Ads.

---

## 6. Schema do banco (Supabase)

Tabelas principais (todas com RLS deny-by-default, acesso via service key):

- `clients` — infoprodutores (slug, ad_account_id, facebook_page_id, daily_budget_cap_cents)
- `campaigns` — campanhas Meta (meta_campaign_id, status, budget_mode CBO/ABO)
- `ad_sets` — conjuntos de anúncios (meta_ad_set_id, targeting jsonb, advantage_audience)
- `ads` — anúncios individuais (meta_ad_id)
- `creatives` — criativos (headline, primary_text, call_to_action_type, image_url)
- `generated_images` — imagens geradas (storage_path, public_url)
- `operation_logs` — audit trail de todas as ações dos agents
- `analyses` — análises de performance (overall_verdict, summary, window_start/stop)
- `metric_snapshots` — snapshots por nível/entidade (impressions, spend_cents, ctr, cplpv_cents, etc.)
- `analysis_findings` — diagnósticos relacionais com severity + recommended_action
- `agent_jobs` — fila de jobs on-demand (kind: create/activate/analyze, status: pending/running/done/failed)
- `agent_events` — telemetria de tool calls (via emit-from-stream.py)
- `funnel_events` — read model do funil visual (impression→click→lpv→view→cart→checkout→purchase)

**Storage buckets** (criar manualmente no Supabase):
- `ad-ingest` — **público** (URLs das imagens precisam ser acessíveis pela Meta)
- `creatives` — privado

---

## 7. Tools disponíveis no Nexus

O Nexus (assistente de voz) tem acesso a 8 tools server-side:

| Tool | Ação |
|---|---|
| `list_clients` | Lista clientes gerenciados |
| `get_client_overview` | Campanhas e dados de um cliente |
| `get_campaign_metrics` | Métricas da última análise |
| `get_latest_analysis` | Veredito + findings da última análise |
| `get_recent_actions` | Log de ações dos agents |
| `get_recent_jobs` | Status de jobs da fila (criação/ativação em andamento) |
| `request_campaign_creation` | Enfileira criação (requer confirmação em 2 turnos) |
| `request_campaign_activation` | Enfileira ativação com gasto real (requer confirmação em 2 turnos) |
| `request_analysis` | Enfileira análise (sem confirmação — é read-only) |

**Allowlist server-side** em `web/lib/nexus/tools.ts`:
- `ENABLED_SLUGS` — array com todos os 15 clientes reais + `cliente-exemplo`
- `CREATE_SKILL_BY_SLUG`, `ACTIVATE_SKILL_BY_SLUG`, `ANALYZE_SKILL_BY_SLUG` derivados do array
- Todas as skills apontam para as versões GENÉRICAS (passam `client_slug` nos args)
- Para adicionar novo cliente: só adicionar slug no `ENABLED_SLUGS` + inserir no Supabase

---

## 8. STATUS ATUAL — O QUE ESTÁ PRONTO

✅ Web dashboard completo (login, overview, detalhe do cliente)
✅ Nexus voice pipeline completo (VAD → STT → chat → TTS)
✅ 3 skills GENÉRICAS headless: create-traffic-campaign, activate-campaign, funnel-analytics-campaign
✅ Todas aceitam `client_slug=<slug>` — lookup dinâmico do cliente no Supabase
✅ 15 clientes reais da agência mapeados e inseridos no Supabase
✅ `web/lib/nexus/tools.ts` atualizado: ENABLED_SLUGS com todos os 15 clientes
✅ `crontab` atualizado: 30 entradas (15 analytics + 15 create, escalonadas por minuto)
✅ Pastas `.claude/materiais-das-empresas/<slug>/` criadas para todos os 15 clientes
✅ Runner EasyPanel (Dockerfile, crontab, scripts) — deploy ativo
✅ Schema Supabase com todas as migrations aplicadas
✅ Fila agent_jobs com claim atômico (RPC claim_agent_job)
✅ Documentação completa (ADRs 0001-0025, how-tos, tutorials, specs)
✅ Rate limiting nas APIs (login, nexus STT/chat/TTS, criação/ativação)
✅ Telemetria de tool calls (emit-from-stream.py → agent_events)
✅ Buckets Supabase criados: `ad-ingest` (público) e `creatives` (privado)
✅ Dashboard deployado na Vercel — login funcionando
✅ `entrypoint.sh` atualizado: configura meta-ads MCP via `META_ADS_MCP_TOKEN` automaticamente
✅ `app/layout.tsx` raiz criado (fix Next.js build)
✅ Facebook Page IDs populados no Supabase para todos os 11 clientes ativos (sessão 5)
✅ `default_landing_url` populado no Supabase para clientes com tráfego para site (sessão 5)
✅ Env vars EasyPanel corrigidas: `ANTHROPIC_API_KEY` e `OPENAI_API_KEY` sem corrupção (sessão 5)
✅ `funnel-analytics-campaign`: histórico de recomendações consultado antes de diagnosticar (commit `cb68256`, sessão 5)
✅ Skill testada com sucesso end-to-end: lulibaby analisada, funil + findings + snapshots no Supabase (sessão 5)
✅ Modelo: `claude-haiku-4-5-20251001` via `CLAUDE_MODEL` no EasyPanel (sessão 5)
✅ Schema banco corrigido: `operation_logs` aceita `analysis`/`analyze`; SKILL.md alinhado (sessão 5)
✅ Custo reduzido: analytics semanal (segunda 08h BRT) + guard spend>0 + criação só via Nexus (sessão 5)
✅ Crontab simplificado: 11 entradas analytics semanais + poll-agent-jobs.sh (sessão 5)

---

## 9. O QUE FALTA — CHECKLIST DE SETUP

### 9.1 Dados por cliente a preencher (por prioridade)

- [ ] `<FACEBOOK_PAGE_ID>` para cada cliente → necessário para criar ads (object_story_spec.page_id)
  - Preencher em `.claude/skills/lista-de-clientes/SKILL.md` (substituir `<XXX_PAGE_ID>`)
  - Ou adicionar coluna `facebook_page_id` na tabela `clients` no Supabase
- [ ] `<META_PIXEL_ID>` para cada cliente → necessário para events de conversão (purchase ROAS)
- [ ] `default_landing_url` para cada cliente → URL da landing page para tráfego
  - Atualizar no Supabase: `UPDATE clients SET default_landing_url='...' WHERE slug='...'`
- [ ] Materiais visuais por cliente: logo, foto, exemplos de ads em `.claude/materiais-das-empresas/<slug>/`

### 9.2 Credenciais (já preenchidas — verificar validade)

- [x] `.env.local` com todas as chaves preenchidas
- [x] Supabase URL + service key
- [x] Anthropic, OpenAI, ElevenLabs, Upstash Redis

### 9.3 Supabase (já configurado)

- [x] Projeto `icxonlpsfnrfcbhdvoiz` criado e ativo
- [x] Todas as migrations aplicadas
- [x] 16 clientes no banco (15 reais + template)
- [ ] Confirmar buckets: `ad-ingest` (público) e `creatives` (privado)

### 9.4 Deploy

- [ ] Deploy do dashboard na Vercel (conectar repo, configurar env vars)
- [ ] Deploy do runner no Fly.io:
  - `fly launch` ou `fly deploy --remote-only`
  - `fly secrets set ...` com todas as env vars
  - Seed OAuth Claude: `fly ssh console` → `claude` → copiar credenciais para `/home/runner/.claude/`
- [ ] Validar cron: `fly ssh console -a meta-ads-agents -C "supercronic -test /app/crontab"`

### 9.5 Opcional / futuro

- [ ] Renomear marca `Nexus`/`Acme` se quiser identidade própria
- [ ] Atualizar nome do app Fly em `fly.toml` (`meta-ads-agents`)
- [ ] Identificar as 7 contas acessíveis não mapeadas (ver `lista-de-clientes/SKILL.md` §final)
- [ ] Resolver targeting BR após aprovação Meta (ver §10)

---

## 10. WORKAROUNDS ATIVOS

### ⚠️ Meta DSA advertiser/payer — targeting US→BR (desde 2026-05-22)

**Problema**: Meta exige registro de advertiser/payer via UI (Ads Manager → Advertising Settings) para criar AdSets com targeting BR. Esse setup não existe na conta ainda. O erro é `100/3858634 verified advertiser missing`.

**Workaround ativo**: a skill `create-traffic-cliente-exemplo-campaign` cria AdSets com `targeting={"countries":["US"]}` como placeholder. O nome do AdSet contém `[NEEDS-RETARGET-BR]`.

**O operador deve**:
1. Após a criação (campanha PAUSED), abrir o Ads Manager
2. Editar o AdSet: trocar targeting US → BR
3. Na edição, a UI força selecionar advertiser/payer — escolher "Nome empresa"
4. Só então ativar a campanha

**Fix definitivo** (reverter workaround quando review aprovado):
1. Submeter form de review Meta: https://www.facebook.com/business/help/1024444835591336
2. Após aprovação (~2 dias úteis), editar `SKILL.md` Step 5.2: mudar `"US"` → `"BR"` e remover `[NEEDS-RETARGET-BR]` do nome do AdSet

**O que NÃO funciona** (já testado):
- Configurar seção UE ou default geral no Advertising Settings UI (silenciosamente revertido pelo backend)
- Passar `dsa_beneficiary`/`dsa_payor` no payload sem o setup UI aprovado

---

## 11. LIMITES DUROS DAS SKILLS (não alterar sem análise)

- Orçamento máximo: **5000 cents (R$50/dia)** por campanha
- Skills de criação: campanhas nascem sempre **PAUSED** — nunca ativa automaticamente
- Skill de ativação: só ativa se campanha pertence ao cliente, está PAUSED e orçamento ≤ cap
- Timeout do runner: **1500 segundos** (25 min) por skill
- Rate limit criação: 1 job por cliente simultâneo (unique index no agent_jobs)

---

## 12. DECISÕES DE ARQUITETURA RELEVANTES

| ADR | Decisão |
|---|---|
| 0001 | Fly.io machine + supercronic para runner 24/7 |
| 0002 | Supabase Postgres para persistência; money em cents; IDs Meta como text |
| 0003 | Bucket `ad-ingest` público (URLs precisam ser acessíveis pela Meta API) |
| 0004 | Schema de análise com findings relacionais (severity, diagnosis, recommendation) |
| 0005 | Web dashboard na Vercel como monorepo (pasta `web/`) |
| 0006 | Auth por senha única + JWT cookie (sem OAuth social) |
| 0009 | Fila agent_jobs no Postgres com RPC `claim_agent_job` atômica (sem QStash) |
| 0011 | VAD via AudioWorklet (processamento de áudio sem bloquear main thread) |
| 0014 | Catálogo de produtos como arquivos JSON no repo (não no DB) |
| 0025 | Read model `funnel_events` para funil visual no dashboard |

---

## 13. COMANDOS ÚTEIS

```bash
# Desenvolvimento local
cd web && npm install && npm run dev

# Testes
cd web && npm test

# Deploy dashboard (Vercel faz auto-deploy no push)
git push

# Runner Fly.io — rodar skill manualmente
fly ssh console -a meta-ads-agents -C "runuser -u runner -- /app/scripts/run-skill.sh create-traffic-cliente-exemplo-campaign"

# Ver logs em tempo real
fly logs -a meta-ads-agents

# Ver último manifest de campanha
fly ssh console -a meta-ads-agents -C "cat /app/tentativas-geracao-de-campanhas/$(ls -t /app/tentativas-geracao-de-campanhas | head -1) | jq ."

# Atualizar secrets no Fly
fly secrets set CHAVE=valor -a meta-ads-agents

# Re-deploy sem cache (atualiza Claude Code CLI)
fly deploy --remote-only --no-cache
```

---

## 14. PRÓXIMAS SESSÕES — O QUE FAZER

**Para colocar no ar (próximos passos prioritários):**
1. Coletar Facebook Page IDs e Pixel IDs de cada cliente (necessários para ads)
2. Preencher `default_landing_url` de cada cliente no Supabase
3. Confirmar buckets Supabase: `ad-ingest` (público) e `creatives` (privado)
4. Deploy dashboard na Vercel
5. Deploy runner no Fly.io + seed OAuth Claude
6. Testar skill analítica via Nexus voice: "analise a performance do cliente brasdente"
7. Testar criação manual: "criar campanha de tráfego para brasdente"
8. Após aprovação Meta, resolver targeting BR (§10)

**Opcional/futuro:**
- Personalizar nome do assistente e marca
- Identificar contas acessíveis não mapeadas (7 contas em `lista-de-clientes`)
- Configurar Cloudflare Turnstile no login
- Adicionar materiais visuais por cliente (logo, foto, ads de referência)

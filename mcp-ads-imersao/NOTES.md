# NOTES — AgencI.A / mcp-ads-imersao
> Última atualização: 2026-08-21

---

## Visão geral do projeto

Agência de tráfego 100% operada por IAs. Duas frentes em paralelo:
- **Meta Ads** — sistema completo (`agents_team_imersao_pro`)
- **Google Ads** — em construção (piloto Luli Baby)

---

## 1. MCPs

### Meta Ads MCP — `mcp-ads-imersao/meta-ads-mcp/`
✅ Funcional. Todos os ajustes aplicados:
- `load_dotenv` com caminho absoluto
- `special_ad_categories` removido do POST
- `starlette` declarado no `requirements.txt`
- `runtime.txt` criado (`python3.12`)
- `vercel.json` com `builds` + `rewrites`
- `.env.example` com placeholders (sem credenciais reais)

✅ **Deploy feito e health check OK.** URL de produção: `https://meta-ads-mcp-xi.vercel.app`
- Endpoint MCP: `https://meta-ads-mcp-xi.vercel.app/mcp`
- Health check: `https://meta-ads-mcp-xi.vercel.app/health`
- Comando para redeploy: `vercel deploy --prod --scope team_oBNQtWNpiXZtipwx1p0m0Xwv`
- ⚠️ Fix aplicado: `vercel.json` usa `routes` + `dest: "/api/index.py"` (não `rewrites`/`destination`)

### Google Ads MCP — `mcp-ads-imersao/google-ads-mcp/`
✅ Funcional. Credenciais configuradas em `.env.local`.
- MCC: `1466534874` (Jasson Oliveira & Co)
- Contas acessíveis: `8955638500`, `4485004600`, `1466534874`

⚠️ **Pendente:** fix no `server.py` (remoção do `pageSize` fixo) já aplicado — entra em vigor no próximo restart do MCP.

---

## 2. Sistema de Agentes Meta Ads — `agents_team_imersao_pro/`

✅ Código completo (dashboard + runner + skills + Supabase schema)
✅ Supabase `icxonlpsfnrfcbhdvoiz` com schema Meta Ads aplicado
✅ 15 clientes reais inseridos (migration `20260821000001_seed_real_clients.sql`)

⚠️ **Pendentes de setup:**
- Preencher `facebook_page_id` e pixel IDs dos clientes no Supabase
- Deploy Vercel (dashboard)
- Deploy Fly.io (runner)
- Seed OAuth Claude no container Fly.io

---

## 3. Sistema de Agentes Google Ads — piloto Luli Baby

**Pasta de trabalho:** `agents_team_imersao_pro/` (mesmo repo, tabelas prefixadas com `google_`)
**Supabase:** mesmo projeto `icxonlpsfnrfcbhdvoiz`
**Cliente piloto:** Luli Baby — `customer_id: 4229872272`, MCC `1466534874`
**KPI:** ROAS sobre purchase WooCommerce (conversion_action `7286570559`) — NUNCA usar `all_conversions`

### Status das migrations
6 arquivos criados em `agents_team_imersao_pro/supabase/migrations/`:

| Arquivo | Status |
|---------|--------|
| `20260821000002_add_google_ads_columns_to_clients.sql` | ✅ Criado — ⚠️ não aplicado |
| `20260821000003_add_google_campaigns.sql` | ✅ Criado — ⚠️ não aplicado |
| `20260821000004_add_google_daily_metrics.sql` | ✅ Criado — ⚠️ não aplicado |
| `20260821000005_add_google_audit_reports.sql` | ✅ Criado — ⚠️ não aplicado |
| `20260821000006_add_google_optimization_suggestions.sql` | ✅ Criado — ⚠️ não aplicado |
| `20260821000007_update_agent_jobs_google_kinds.sql` | ✅ Criado — ⚠️ não aplicado |

### Próximos passos (em ordem)

**PASSO 1 — Aplicar as migrations no Supabase**
- URL: https://supabase.com/dashboard/project/icxonlpsfnrfcbhdvoiz/sql/new
- Rodar cada arquivo em ordem (`000002` → `000007`)
- Verificar: `SELECT slug, google_customer_id FROM clients WHERE google_customer_id IS NOT NULL;`
- Deve retornar 6 linhas: lulibaby, piemon, bpure, clorin, bombapatch, armando

**PASSO 2 — Criar as 5 skills headless**
Em `agents_team_imersao_pro/.claude/skills/`:
- `daily-report-lulibaby/SKILL.md`
- `audit-lulibaby/SKILL.md`
- `negative-keywords-lulibaby/SKILL.md`
- `ad-copy-lulibaby/SKILL.md`
- `apply-suggestion-lulibaby/SKILL.md`

**PASSO 3 — Scripts Python de escrita na Google Ads API**
Em `agents_team_imersao_pro/scripts/apply/`:
- `apply_negative_keywords.py` (adaptar de `Claude_GoogleAds/scripts/lulibaby_aplicar_semana1.py`)
- `apply_budget_adjustment.py`
- `apply_pause_resource.py`

**PASSO 4 — Adaptar Dockerfile + crontab**
- Adicionar `pip3 install google-ads python-dotenv` no Dockerfile
- Crontab:
  ```
  0 8 * * *   /app/scripts/run-skill.sh daily-report-lulibaby
  0 9 * * 1   /app/scripts/run-skill.sh audit-lulibaby
  30 9 * * 1  /app/scripts/run-skill.sh negative-keywords-lulibaby
  * * * * *   /app/scripts/poll-agent-jobs.sh
  ```

**PASSO 5 — Adaptar dashboard Next.js**
- Página `/dashboard/suggestions` — sugestões pendentes de aprovação
- Página `/dashboard/audits` — histórico de auditorias
- Adaptar Nexus tools: `approve_suggestion`, `get_daily_metrics`, `get_latest_audit`

**PASSO 6 — Deploy Fly.io + secrets Google Ads**
```bash
fly secrets set GOOGLE_ADS_DEVELOPER_TOKEN=...
fly secrets set GOOGLE_ADS_CLIENT_ID=...
fly secrets set GOOGLE_ADS_CLIENT_SECRET=...
fly secrets set GOOGLE_ADS_REFRESH_TOKEN=...
fly secrets set GOOGLE_ADS_LOGIN_CUSTOMER_ID=1466534874
```

**PASSO 7 — Teste end-to-end**
- Rodar `daily-report-lulibaby` manualmente no runner
- Verificar inserção em `google_daily_metrics`
- Rodar `audit-lulibaby` e aprovar sugestão via Nexus

---

## Onde abrir cada chat

| Frente | Pasta para abrir no Claude Code |
|--------|--------------------------------|
| Google Ads agents (continuação) ← **PRÓXIMA SESSÃO** | `C:\Users\User\Desktop\Projetos IA\AgencI.A\agents_team_imersao_pro` |
| Meta Ads MCP | `C:\Users\User\Desktop\Projetos IA\AgencI.A\mcp-ads-imersao\meta-ads-mcp` |
| Google Ads MCP | `C:\Users\User\Desktop\Projetos IA\AgencI.A\mcp-ads-imersao\google-ads-mcp` |
| Workspace análises (scripts Python) | `C:\Users\User\Desktop\Projetos IA\Claude_GoogleAds` |

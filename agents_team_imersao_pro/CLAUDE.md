# Project: agents_team_meta_ads_entrada

**Missão**: Criamos uma agência de tráfego para Meta Ads (Facebook Ads) 100% feita por IAs que opera 24/7.

> Esta é a versão de ENTRADA do template: dashboard com a visão geral + chat de voz com o
> Ultron/Nexus + ativação de agents no backend (fila `agent_jobs` → runner Fly.io → skills).
> As capacidades são: criar campanha de tráfego, ativar campanha e análise de performance.

**Importante**: A autentificação do usuário na Meta já foi feita no momento da vinculação do MCP da Meta. Sempre use apenas o MCP da Meta para criar campanhas. Caso tenha dúvidas sobre como fazer, verifique se o próprio MCP tem instruções de como prosseguir.

## Como configurar do zero

Para tornar o template seu (credenciais, slug, marca), veja `docs/how-to/setup-do-zero.md`.
Operação do dia a dia: `docs/how-to/operations-runbook.md`.

## Workflow

**Instruções gerais**:
- em ".claude\materiais-das-empresas" você encontrará informações adicionais sobre as empresas como "logo"(.claude\materiais-das-empresas\cliente-exemplo\logo\logo.png), imagem do infoprodutor (.claude\materiais-das-empresas\cliente-exemplo\logo\foto-do-infoprodutor\nome-do-cliente.jpg) e exemplos de anúncios que o infoprodutor já usou antes (.claude\materiais-das-empresas\cliente-exemplo\exemplo-de-ads\meta-ads-agents.png).
- em ".claude\skills\lista-de-clientes\SKILL.md" você encontrará informações sobre os clientes como número da BM, conta de anúncios, URL, regras de orçamento etc.
- sempre atualize sua memoria de projeto após uma execução bem sucedida de criação de campanha e de análise para que você aprenda com seus resultados.

## Stack

- **Web dashboard** (`web/`): TypeScript 5.6 + Node 22 + Next.js 15 (App Router) + React 19 + Tailwind 4; API via Hono num route handler catch-all
- **Auth do dashboard**: senha única do operador (SHA-256) + cookie JWT (`jose`) — ADR 0006
- **DB**: Supabase Postgres (migrations em `supabase/migrations/`, RLS deny-by-default; acesso server-side via service key)
- **Fila de jobs**: tabela `agent_jobs` no Postgres + RPC `claim_agent_job` (ADR 0009) — sem QStash
- **Cache / memória do Nexus**: Upstash Redis (free tier)
- **Voz do Nexus**: STT Whisper (OpenAI) + TTS ElevenLabs + VAD via AudioWorklet (ADR 0011)
- **AI**: Anthropic SDK — chat do Nexus com `claude-sonnet-4-6` (env `NEXUS_MODEL`), prompt cache obrigatório
- **MCP**: `meta-ads-mcp` como connector (usado pelas skills no runner)
- **Runner 24/7**: Fly.io machine (region `gru`) com supercronic + Claude Code CLI (`Dockerfile`, `fly.toml`, `crontab`) — ADR 0001
- **Cloud**: Vercel (dashboard, region `gru1`) + Supabase (region `sa-east-1`) + Fly.io (runner)

**Banco de Dados**: as informações de cada campanha, conjuntos, anúncios, creativos, o que foi criado, edições etc. devem ser salvos no banco de dados do Supabase (sempre via integração do MCP).

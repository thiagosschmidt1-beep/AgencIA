-- Migration: add_google_optimization_suggestions
-- Coração do fluxo semi-automático: agents gravam sugestões aqui →
-- operador aprova no dashboard → runner executa script Python na Google Ads API.
--
-- Fluxo:
--   1. skill (audit / negative-keywords) cria suggestion com status='pending'
--   2. Dashboard/Nexus exibe sugestões pendentes com impacto estimado
--   3. Operador aprova → status='approved' + agent_job kind='google_apply' enfileirado
--   4. Runner executa scripts/apply/<tipo>.py com payload_json
--   5. Script atualiza status='applied' ou 'failed' + grava apply_log

create table public.google_optimization_suggestions (
  id                    uuid primary key default gen_random_uuid(),
  client_id             uuid not null references public.clients(id) on delete cascade,
  audit_id              uuid references public.google_audit_reports(id) on delete set null,
  suggestion_type       text not null
                          check (suggestion_type in (
                            'negative_keyword','budget_adjustment',
                            'pause_keyword','pause_ad_group','ad_copy','other'
                          )),
  campaign_id           text,
  campaign_name         text,
  title                 text not null,               -- "Negativar 12 termos irrelevantes"
  rationale             text not null,               -- justificativa legível pelo operador
  estimated_impact_brl  numeric(12,2),               -- economia estimada em BRL/mês
  estimated_roas_delta  numeric(8,4),                -- impacto estimado no ROAS
  payload_json          jsonb not null default '{}', -- argumentos para o script Python
  status                text not null default 'pending'
                          check (status in ('pending','approved','rejected','applied','failed')),
  requested_by          text not null default 'agent'
                          check (requested_by in ('agent','nexus','manual')),
  reviewed_by           text,
  reviewed_at           timestamptz,
  applied_at            timestamptz,
  apply_job_id          uuid,                        -- FK para agent_jobs (preenchida ao aprovar)
  apply_log             text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index google_opt_suggestions_client_status_idx
  on public.google_optimization_suggestions (client_id, status, created_at desc);
create index google_opt_suggestions_audit_id_idx
  on public.google_optimization_suggestions (audit_id);

create trigger set_google_opt_suggestions_updated_at
  before update on public.google_optimization_suggestions
  for each row execute function public.set_updated_at();

alter table public.google_optimization_suggestions enable row level security;

-- Lote de palavras-chave negativas a aplicar em campanhas.
-- Criado pela skill negative-keywords-lulibaby.
-- Cada batch tem uma lista jsonb de {text, match_type} e o escopo de aplicação.
create table public.google_negative_keyword_batches (
  id                    uuid primary key default gen_random_uuid(),
  client_id             uuid not null references public.clients(id) on delete cascade,
  suggestion_id         uuid references public.google_optimization_suggestions(id) on delete set null,
  scope                 text not null check (scope in ('campaign','shared_list')),
  campaign_id           text,                    -- nulo se scope='shared_list'
  shared_list_id        text,                    -- nulo se scope='campaign'
  keywords              jsonb not null,          -- [{text: "...", match_type: "PHRASE|EXACT|BROAD"}, ...]
  keyword_count         integer not null default 0,
  estimated_waste_brl   numeric(12,2),           -- gasto desperdiçado dos últimos 30d coberto pelos termos
  status                text not null default 'pending'
                          check (status in ('pending','approved','applied','failed','rejected')),
  applied_at            timestamptz,
  apply_log             text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index google_neg_batches_client_status_idx
  on public.google_negative_keyword_batches (client_id, status, created_at desc);

create trigger set_google_neg_batches_updated_at
  before update on public.google_negative_keyword_batches
  for each row execute function public.set_updated_at();

alter table public.google_negative_keyword_batches enable row level security;

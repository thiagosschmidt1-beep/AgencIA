-- Migration: add_google_audit_reports
-- Auditorias semanais da conta Google Ads por cliente.
-- skill audit-lulibaby roda toda segunda 09h e grava aqui.
-- Uma auditoria = um google_audit_reports + N google_audit_findings.

create table public.google_audit_reports (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients(id) on delete cascade,
  window_start     date not null,
  window_stop      date not null,
  health_score     smallint check (health_score between 1 and 10),
  overall_verdict  text not null
                     check (overall_verdict in ('healthy','watch','critical','no_data','error')),
  executive_summary text,
  triggered_by     text not null default 'cron'
                     check (triggered_by in ('cron','nexus','manual')),
  run_started_at   timestamptz,
  run_finished_at  timestamptz,
  created_at       timestamptz not null default now()
);

create index google_audit_reports_client_id_idx on public.google_audit_reports (client_id, created_at desc);

alter table public.google_audit_reports enable row level security;

-- Achados individuais dentro de uma auditoria.
-- category cobre os principais eixos de análise PPC.
-- estimated_impact_brl = economia ou receita adicional estimada em BRL.
create table public.google_audit_findings (
  id                    uuid primary key default gen_random_uuid(),
  audit_id              uuid not null references public.google_audit_reports(id) on delete cascade,
  client_id             uuid not null references public.clients(id) on delete cascade,
  campaign_id           text,
  campaign_name         text,
  severity              text not null
                          check (severity in ('info','low','medium','high','critical')),
  category              text not null
                          check (category in (
                            'waste','negative_keyword','bid_strategy','budget',
                            'ad_copy','quality_score','conversion_tracking',
                            'search_term','asset','audience','other'
                          )),
  diagnosis             text not null,
  evidence              jsonb,
  recommended_action    text,
  estimated_impact_brl  numeric(12,2),
  created_at            timestamptz not null default now()
);

create index google_audit_findings_audit_id_idx  on public.google_audit_findings (audit_id);
create index google_audit_findings_client_id_idx on public.google_audit_findings (client_id, severity);

alter table public.google_audit_findings enable row level security;

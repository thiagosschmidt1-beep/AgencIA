-- Migration: add_google_daily_metrics
-- Métricas diárias por campanha Google Ads.
-- Gerado pela skill daily-report-lulibaby (todo dia 08h, dados do dia anterior já fechados).
-- Uma linha por (client_id, campaign_id, metric_date) — unique constraint garante idempotência.
--
-- REGRA CRÍTICA: conversions e conversions_value usam APENAS a conversion_action_id
-- configurada em clients.google_conversion_action_id.
-- NUNCA usar metrics.all_conversions nesta tabela.

create table public.google_daily_metrics (
  id                uuid primary key default gen_random_uuid(),
  client_id         uuid not null references public.clients(id) on delete cascade,
  campaign_id       text not null,               -- ID da campanha no Google Ads
  campaign_name     text,
  metric_date       date not null,
  impressions       bigint not null default 0,
  clicks            integer not null default 0,
  cost_micros       bigint not null default 0,   -- custo em micros (dividir por 1e6 para BRL)
  conversions       numeric(12,4) not null default 0,
  conversions_value numeric(14,2) not null default 0,  -- receita em BRL
  roas              numeric(10,4),               -- conversions_value / (cost_micros / 1e6)
  cpa_brl           numeric(10,2),               -- (cost_micros / 1e6) / conversions
  cpc_brl           numeric(10,4),               -- (cost_micros / 1e6) / clicks
  ctr               numeric(10,6),               -- clicks / impressions
  raw               jsonb,                       -- payload bruto do Google Ads API
  captured_at       timestamptz not null default now(),
  unique (client_id, campaign_id, metric_date)
);

create index google_daily_metrics_client_date_idx on public.google_daily_metrics (client_id, metric_date desc);
create index google_daily_metrics_campaign_idx    on public.google_daily_metrics (campaign_id, metric_date desc);

alter table public.google_daily_metrics enable row level security;

-- Migration: add_google_campaigns
-- Espelho das campanhas Google Ads ativas por cliente.
-- Populado e atualizado pela skill audit-lulibaby (e futuros audits de outros clientes).
-- campaign_id = ID numérico da campanha no Google Ads (text, opaco, sem hifens).
-- budget_micros = orçamento diário em micros (1 BRL = 1_000_000 micros).

create table public.google_campaigns (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients(id) on delete cascade,
  campaign_id      text not null unique,         -- '23621254246'
  name             text not null,
  campaign_type    text not null,                -- 'PERFORMANCE_MAX', 'SEARCH', 'DISPLAY', 'SHOPPING'
  status           text not null default 'ENABLED'
                     check (status in ('ENABLED','PAUSED','REMOVED')),
  budget_micros    bigint,                       -- orçamento diário em micros
  bidding_strategy text,                         -- 'TARGET_ROAS', 'MAXIMIZE_CONVERSION_VALUE', etc.
  target_roas      numeric(8,4),                 -- ex: 7.5 (750%)
  spend_share_pct  numeric(5,2),                 -- % do gasto total da conta (atualizado na auditoria)
  last_synced_at   timestamptz,
  raw_spec         jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index google_campaigns_client_id_idx on public.google_campaigns (client_id);

create trigger set_google_campaigns_updated_at
  before update on public.google_campaigns
  for each row execute function public.set_updated_at();

alter table public.google_campaigns enable row level security;

-- Seed: campanhas ativas conhecidas da Luli Baby.
-- Fonte: optimization-db/4229872272_lulibaby.json
insert into public.google_campaigns (client_id, campaign_id, name, campaign_type, status, spend_share_pct)
select c.id, '23621254246', 'PMax Luli Baby', 'PERFORMANCE_MAX', 'ENABLED', 82.0
  from public.clients c where c.slug = 'lulibaby'
on conflict (campaign_id) do nothing;

insert into public.google_campaigns (client_id, campaign_id, name, campaign_type, status, spend_share_pct)
select c.id, '23570005416', 'Search Marca Luli Baby', 'SEARCH', 'ENABLED', 18.0
  from public.clients c where c.slug = 'lulibaby'
on conflict (campaign_id) do nothing;

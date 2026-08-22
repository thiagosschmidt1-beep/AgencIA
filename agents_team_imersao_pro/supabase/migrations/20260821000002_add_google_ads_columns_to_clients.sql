-- Migration: add_google_ads_columns_to_clients
-- Adiciona colunas Google Ads na tabela clients existente (Meta Ads).
-- Nullable: nem todo cliente tem conta Google Ads.
-- Convenções:
--   * google_customer_id = ID numérico sem hifens ('4229872272')
--   * google_mcc_customer_id = MCC pai ('1466534874')
--   * google_conversion_action_id = ação primária válida para KPI (NUNCA all_conversions)
--   * google_daily_budget_cap_brl = limite de segurança em BRL (Google trabalha em micros;
--     scripts convertem: brl * 1_000_000 = micros)

alter table public.clients
  add column if not exists google_customer_id          text unique,
  add column if not exists google_mcc_customer_id      text,
  add column if not exists google_conversion_action_id text,
  add column if not exists google_daily_budget_cap_brl numeric(10,2);

-- Seed: vincular clientes já existentes aos IDs Google Ads.
-- Fonte: Claude_GoogleAds/CLAUDE.md + optimization-db/*.json (MCC 1466534874).
update public.clients set
  google_customer_id          = '4229872272',
  google_mcc_customer_id      = '1466534874',
  google_conversion_action_id = '7286570559',  -- Google for WooCommerce purchase. NUNCA usar all_conversions.
  google_daily_budget_cap_brl = 100.00
where slug = 'lulibaby';

update public.clients set
  google_customer_id          = '2619123605',
  google_mcc_customer_id      = '1466534874',
  google_daily_budget_cap_brl = 100.00
where slug = 'piemon';

update public.clients set
  google_customer_id          = '5719969171',
  google_mcc_customer_id      = '1466534874',
  google_daily_budget_cap_brl = 100.00
where slug = 'bpure';

update public.clients set
  google_customer_id          = '8273488674',
  google_mcc_customer_id      = '1466534874',
  google_daily_budget_cap_brl = 100.00
where slug = 'clorin';

update public.clients set
  google_customer_id          = '5255297003',
  google_mcc_customer_id      = '1466534874',
  google_daily_budget_cap_brl = 100.00
where slug = 'bombapatch';

update public.clients set
  google_customer_id          = '4723061810',
  google_mcc_customer_id      = '1466534874',
  google_daily_budget_cap_brl = 100.00
where slug = 'armando';

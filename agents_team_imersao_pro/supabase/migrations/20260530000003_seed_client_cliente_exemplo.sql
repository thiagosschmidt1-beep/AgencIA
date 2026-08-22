-- Migration: seed_client_cliente-exemplo
-- Seeds the cliente-exemplo client row required by both Fly.io cron skills.
-- Both skills do `SELECT id FROM clients WHERE slug='cliente-exemplo'` and abort if absent.
-- Source of truth: .claude/skills/lista-de-clientes/SKILL.md
-- Idempotent: re-running refreshes the known columns without duplicating.

insert into public.clients (
  slug, name, ad_account_id, business_manager_id, facebook_page_id,
  default_landing_url, daily_budget_cap_cents, currency, materials_path
) values (
  'cliente-exemplo',
  'cliente-exemplo — Curso Exemplo (CURSO)',
  '<AD_ACCOUNT_ID>',
  '<BUSINESS_MANAGER_ID>',
  '<FACEBOOK_PAGE_ID>',
  'https://curso-exemplo.example.com',
  5000,
  'BRL',
  '.claude/materiais-das-empresas/cliente-exemplo/'
)
on conflict (slug) do update set
  name                   = excluded.name,
  ad_account_id          = excluded.ad_account_id,
  business_manager_id    = excluded.business_manager_id,
  facebook_page_id       = excluded.facebook_page_id,
  default_landing_url    = excluded.default_landing_url,
  daily_budget_cap_cents = excluded.daily_budget_cap_cents,
  currency               = excluded.currency,
  materials_path         = excluded.materials_path;

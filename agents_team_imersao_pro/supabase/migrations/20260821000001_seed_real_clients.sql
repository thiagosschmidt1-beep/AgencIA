-- Migration: seed_real_clients
-- Insere os 15 clientes reais da agência descobertos via Meta Ads API (2026-08-21).
-- Page IDs e Pixel IDs a preencher quando disponíveis (necessários para criação de campanhas).
-- O seed do cliente-exemplo (20260530000003) é mantido para referência; este arquivo adiciona os reais.
-- Todos usam daily_budget_cap_cents = 5000 (R$50) como limite de segurança para criação automática.

INSERT INTO public.clients (slug, name, ad_account_id, default_landing_url, daily_budget_cap_cents, currency, materials_path)
VALUES
  ('brasdente',       'Brasdente',              '1069409921363168', null, 5000, 'BRL', '.claude/materiais-das-empresas/brasdente'),
  ('bombapatch',      'Bombapatch',             '1019769737168473', null, 5000, 'BRL', '.claude/materiais-das-empresas/bombapatch'),
  ('bpure',           'Bpure Ecommerce',        '851938083483833',  null, 5000, 'BRL', '.claude/materiais-das-empresas/bpure'),
  ('cardsofparadise', 'Cards Of Paradise',      '1054871085321918', null, 5000, 'BRL', '.claude/materiais-das-empresas/cardsofparadise'),
  ('clorin',          'Clorin',                 '1152309295351651', null, 5000, 'BRL', '.claude/materiais-das-empresas/clorin'),
  ('coutinho',        'Coutinho Incorporacoes', '583640952921224',  null, 5000, 'BRL', '.claude/materiais-das-empresas/coutinho'),
  ('dolcevivere',     'Dolce Vivere',           '1352822116344860', null, 5000, 'BRL', '.claude/materiais-das-empresas/dolcevivere'),
  ('lulibaby',        'Lulibaby',               '547504311493941',  null, 5000, 'BRL', '.claude/materiais-das-empresas/lulibaby'),
  ('originalflex',    'Original Flex',          '2551619881886028', null, 5000, 'BRL', '.claude/materiais-das-empresas/originalflex'),
  ('piemon',          'Piemon Atacarejo',       '147401468324992',  null, 5000, 'BRL', '.claude/materiais-das-empresas/piemon'),
  ('firebull',        'Firebull',               '439310134113499',  null, 5000, 'BRL', '.claude/materiais-das-empresas/firebull'),
  ('popular',         'Popular',                '1541265036021088', null, 5000, 'BRL', '.claude/materiais-das-empresas/popular'),
  ('daniele-melo',    'Daniele Melo',           '667257706249011',  null, 5000, 'BRL', '.claude/materiais-das-empresas/daniele-melo'),
  ('armando',         'Armando Pre Moldados',   '105700106495046',  null, 5000, 'BRL', '.claude/materiais-das-empresas/armando'),
  ('dpo-board',       'DPO Board',              '1417900892867332', null, 5000, 'BRL', '.claude/materiais-das-empresas/dpo-board')
ON CONFLICT (slug) DO UPDATE SET
  name           = EXCLUDED.name,
  ad_account_id  = EXCLUDED.ad_account_id,
  materials_path = EXCLUDED.materials_path,
  updated_at     = now();

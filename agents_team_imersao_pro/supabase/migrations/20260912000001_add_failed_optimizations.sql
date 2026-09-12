-- Migration: add failed_optimizations table
-- Banco de otimizações fracassadas por cliente — alimentado pela skill optimize-campaign
-- e consultado antes de qualquer sugestão nova para evitar repetir erros já conhecidos.

create table public.failed_optimizations (
  -- Chave no formato <PREFIX>-YYYY-NNN (ex: LUL-2026-001)
  id              text        primary key,
  client_slug     text        not null references public.clients(slug) on delete cascade,
  account_id      text        not null,

  -- O que aconteceu
  data_acao       text        not null, -- texto livre pois algumas datas são intervalos/ranges
  tipo_otimizacao text        not null,
  padrao          text,                 -- nome curto do padrão (ex: "pausar_vencedor")
  severidade      text,                 -- "alta" | "media" | "baixa"
  status_atual    text,

  -- Entidades Meta envolvidas (campaign_id, adset_id, ad_id, nomes)
  entidade        jsonb       not null default '{}',

  -- Narrativa
  acao_tomada          text,
  por_que_nao_deu_certo text,
  recomendacao         text,
  custo_do_aprendizado text,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Trigger de updated_at
create trigger failed_optimizations_updated_at
  before update on public.failed_optimizations
  for each row execute function public.set_updated_at();

-- Índices para consultas frequentes da skill
create index idx_failed_optimizations_client_slug on public.failed_optimizations(client_slug);
create index idx_failed_optimizations_padrao      on public.failed_optimizations(padrao) where padrao is not null;
create index idx_failed_optimizations_tipo        on public.failed_optimizations(tipo_otimizacao);

-- RLS: deny-by-default (acesso via service key no runner)
alter table public.failed_optimizations enable row level security;

comment on table public.failed_optimizations is
  'Log de otimizações que já foram tentadas e não deram certo. Consultado pela skill optimize-campaign antes de sugerir qualquer ação para evitar repetir erros conhecidos. Alimentado automaticamente após cada ciclo de análise.';

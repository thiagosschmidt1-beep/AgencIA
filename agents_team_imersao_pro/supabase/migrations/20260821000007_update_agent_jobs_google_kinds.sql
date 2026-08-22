-- Migration: update_agent_jobs_google_kinds
-- Adiciona kinds Google Ads na tabela agent_jobs existente (Meta Ads).
-- Novos kinds:
--   'google_report' — skill daily-report-lulibaby (cron diário, leitura)
--   'google_audit'  — skill audit-lulibaby (cron semanal, leitura + sugestões)
--   'google_apply'  — skill apply-suggestion-lulibaby (on-demand, escrita na API)
--
-- Estratégia para o check constraint:
--   PostgreSQL não permite ALTER de check constraints — é necessário dropar e recriar.
--   A tabela agent_jobs pode ter dados; a operação é segura pois nenhum dado existente
--   usa os novos kinds.
--
-- Estratégia para o unique index:
--   O índice existente (client_id, kind) WHERE status IN (...) garante single-flight por kind.
--   Para 'google_apply' isso é restritivo demais: múltiplas sugestões podem ser aprovadas
--   e aplicadas em sequência para o mesmo cliente. Solução: recriar o índice excluindo
--   'google_apply' e adicionar índice separado por (client_id, suggestion_id) para apply.

-- 1. Dropar constraint existente e recriar com kinds Google Ads incluídos.
alter table public.agent_jobs
  drop constraint agent_jobs_kind_check;

alter table public.agent_jobs
  add constraint agent_jobs_kind_check
  check (kind in ('create','activate','analyze','summarize','google_report','google_audit','google_apply'));

-- 2. Recriar o unique index de single-flight excluindo 'google_apply'.
drop index if exists public.agent_jobs_one_active_per_kind;

create unique index agent_jobs_one_active_per_kind
  on public.agent_jobs (client_id, kind)
  where status in ('pending','claimed','running')
    and kind not in ('google_apply');

-- 3. Para google_apply: single-flight por (client_id, suggestion_id).
--    Impede aprovar a mesma sugestão duas vezes enquanto o apply ainda está rodando.
create unique index agent_jobs_one_apply_per_suggestion
  on public.agent_jobs (client_id, (args->>'suggestion_id'))
  where kind = 'google_apply'
    and status in ('pending','claimed','running');

-- 4. Atualizar operation_logs.entity_type para incluir entidades Google Ads.
alter table public.operation_logs
  drop constraint operation_logs_entity_type_check;

alter table public.operation_logs
  add constraint operation_logs_entity_type_check
  check (entity_type in (
    'client','campaign','ad_set','ad','creative','image',
    'google_campaign','google_suggestion','google_neg_batch','google_audit','google_report'
  ));

-- 5. Atualizar operation_logs.action para incluir ações Google Ads.
alter table public.operation_logs
  drop constraint operation_logs_action_check;

alter table public.operation_logs
  add constraint operation_logs_action_check
  check (action in (
    'create','update','delete','activate','pause',
    'approve','reject','apply','report'
  ));

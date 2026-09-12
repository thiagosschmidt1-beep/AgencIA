-- Migration: add_optimize_kind_to_agent_jobs
-- Adiciona kind 'optimize' na tabela agent_jobs para a skill optimize-campaign.
-- Também adiciona 'optimize' e 'record_failure' em operation_logs para rastreabilidade.

-- 1. Dropar e recriar check constraint de kind com 'optimize' incluído.
alter table public.agent_jobs
  drop constraint agent_jobs_kind_check;

alter table public.agent_jobs
  add constraint agent_jobs_kind_check
  check (kind in ('create','activate','analyze','summarize','google_report','google_audit','google_apply','optimize'));

-- 2. O unique index agent_jobs_one_active_per_kind já exclui 'google_apply'.
--    Para 'optimize' o comportamento padrão (single-flight por cliente) é correto:
--    apenas uma análise/aplicação de otimização por vez por cliente.
--    Nenhuma alteração necessária no índice.

-- 3. Adicionar 'optimize' e 'record_failure' em operation_logs.entity_type.
alter table public.operation_logs
  drop constraint operation_logs_entity_type_check;

alter table public.operation_logs
  add constraint operation_logs_entity_type_check
  check (entity_type in (
    'client','campaign','ad_set','ad','creative','image',
    'google_campaign','google_suggestion','google_neg_batch','google_audit','google_report',
    'optimization'
  ));

-- 4. Adicionar 'optimize' em operation_logs.action.
alter table public.operation_logs
  drop constraint operation_logs_action_check;

alter table public.operation_logs
  add constraint operation_logs_action_check
  check (action in (
    'create','update','delete','activate','pause',
    'approve','reject','apply','report','optimize'
  ));

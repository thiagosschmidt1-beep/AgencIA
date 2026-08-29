-- Migration: expand_operation_logs_constraints
-- Expande os CHECK constraints de operation_logs para aceitar
-- entity_type='analysis' e action='analyze', usados pela skill funnel-analytics-campaign.

ALTER TABLE public.operation_logs
  DROP CONSTRAINT IF EXISTS operation_logs_entity_type_check;

ALTER TABLE public.operation_logs
  ADD CONSTRAINT operation_logs_entity_type_check
  CHECK (entity_type IN ('client','campaign','ad_set','ad','creative','image','analysis'));

ALTER TABLE public.operation_logs
  DROP CONSTRAINT IF EXISTS operation_logs_action_check;

ALTER TABLE public.operation_logs
  ADD CONSTRAINT operation_logs_action_check
  CHECK (action IN ('create','update','delete','activate','pause','analyze'));

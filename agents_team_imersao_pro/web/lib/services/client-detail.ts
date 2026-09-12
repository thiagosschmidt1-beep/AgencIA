import "server-only";
import { db } from "@/lib/db/client";
import type {
  Analysis,
  AnalysisFinding,
  Campaign,
  Client,
  Creative,
  MetricSnapshot,
} from "@/lib/db/types";

export type OptimizationJob = {
  id: string;
  status: string;
  created_at: string;
  finished_at: string | null;
  result: unknown;
};

export type OptimizationSuggestion = {
  id: string;
  prioridade: string;
  tipo_otimizacao: string;
  entidade_nome?: string;
  entidade_id?: string;
  acao: string;
  impacto_esperado: string;
  risco?: string;
};

export type ClientDetail = {
  client: Client;
  campaigns: Campaign[];
  creatives: Array<
    Pick<
      Creative,
      "id" | "headline" | "primary_text" | "call_to_action_type" | "image_url" | "link_url"
    >
  >;
  latestAnalysis: {
    analysis: Analysis;
    snapshots: MetricSnapshot[];
    findings: AnalysisFinding[];
  } | null;
};

/**
 * Full read for a single client's detail page: campaigns, creatives, and the most
 * recent performance analysis (snapshots + diagnostic findings). Read-only.
 * Returns null if the slug does not exist.
 */
export async function getClientDetail(slug: string): Promise<ClientDetail | null> {
  const supabase = db();

  const clientRes = await supabase.from("clients").select("*").eq("slug", slug).maybeSingle();
  if (clientRes.error) throw clientRes.error;
  if (!clientRes.data) return null;
  const client = clientRes.data;

  const [campaignsRes, creativesRes, analysisRes] = await Promise.all([
    supabase
      .from("campaigns")
      .select("*")
      .eq("client_id", client.id)
      .order("created_at", { ascending: false }),
    supabase
      .from("creatives")
      .select("id, headline, primary_text, call_to_action_type, image_url, link_url")
      .eq("client_id", client.id)
      .order("created_at", { ascending: false })
      .limit(12),
    supabase
      .from("analyses")
      .select("*")
      .eq("client_id", client.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  if (campaignsRes.error) throw campaignsRes.error;
  if (creativesRes.error) throw creativesRes.error;
  if (analysisRes.error) throw analysisRes.error;

  let latestAnalysis: ClientDetail["latestAnalysis"] = null;
  if (analysisRes.data) {
    const analysis = analysisRes.data;
    const [snapshotsRes, findingsRes] = await Promise.all([
      supabase
        .from("metric_snapshots")
        .select("*")
        .eq("analysis_id", analysis.id)
        .order("spend_cents", { ascending: false }),
      supabase
        .from("analysis_findings")
        .select("*")
        .eq("analysis_id", analysis.id)
        .order("severity", { ascending: true }),
    ]);
    if (snapshotsRes.error) throw snapshotsRes.error;
    if (findingsRes.error) throw findingsRes.error;
    latestAnalysis = {
      analysis,
      snapshots: snapshotsRes.data ?? [],
      findings: findingsRes.data ?? [],
    };
  }

  return {
    client,
    campaigns: campaignsRes.data ?? [],
    creatives: creativesRes.data ?? [],
    latestAnalysis,
  };
}

/**
 * Returns the most recent optimize job for a client (any status).
 * Used to show pending/done suggestions on the client detail page.
 */
export async function getPendingOptimizations(clientId: string): Promise<OptimizationJob | null> {
  const { data, error } = await db()
    .from("agent_jobs")
    .select("id, status, created_at, finished_at, result")
    .eq("client_id", clientId)
    .eq("kind", "optimize")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

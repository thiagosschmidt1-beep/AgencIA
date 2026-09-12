"use client";

import { useState } from "react";
import type { OptimizationJob, OptimizationSuggestion } from "@/lib/services/client-detail";

const PRIORITY_STYLES: Record<string, string> = {
  alta: "border-red-400/40 bg-red-500/10 text-red-300",
  media: "border-yellow-400/40 bg-yellow-500/10 text-yellow-300",
  baixa: "border-green-400/40 bg-green-500/10 text-green-300",
};

function parseSuggestions(result: unknown): OptimizationSuggestion[] {
  if (!result || typeof result !== "object") return [];
  const r = result as Record<string, unknown>;
  return Array.isArray(r.suggestions) ? (r.suggestions as OptimizationSuggestion[]) : [];
}

type Props = {
  clientSlug: string;
  optimizationJob: OptimizationJob | null;
};

export function OptimizationSection({ clientSlug, optimizationJob }: Props) {
  const suggestions = optimizationJob?.status === "done" ? parseSuggestions(optimizationJob.result) : [];
  const [selected, setSelected] = useState<Set<string>>(new Set(suggestions.map((s) => s.id)));
  const [state, setState] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  const toggleSuggestion = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleApprove = async () => {
    if (selected.size === 0) return;
    setState("loading");
    setErrorMsg("");
    try {
      const res = await fetch("/api/optimizations/approve", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ client_slug: clientSlug, suggestion_ids: Array.from(selected) }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        const msg = (body as { error?: string }).error ?? `erro ${res.status}`;
        if (msg === "already_in_progress") {
          setErrorMsg("Já existe uma otimização em andamento para este cliente.");
        } else {
          setErrorMsg(`Falha ao enfileirar: ${msg}`);
        }
        setState("error");
        return;
      }
      setState("success");
    } catch {
      setErrorMsg("Erro de rede. Tente novamente.");
      setState("error");
    }
  };

  if (!optimizationJob) {
    return (
      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-white">Sugestões de Otimização</h2>
        <p className="text-sm text-white/50">
          Nenhuma análise de otimização ainda. Peça ao Nexus para rodar uma.
        </p>
      </section>
    );
  }

  if (optimizationJob.status === "pending" || optimizationJob.status === "running") {
    return (
      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-white">Sugestões de Otimização</h2>
        <div className="tech-panel rounded-lg px-4 py-3">
          <p className="text-sm text-white/70">
            <span className="mr-2 inline-block h-2 w-2 animate-pulse rounded-full bg-cyan-400" />
            Análise em andamento — os agents estão gerando sugestões…
          </p>
        </div>
      </section>
    );
  }

  if (optimizationJob.status === "failed") {
    return (
      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-white">Sugestões de Otimização</h2>
        <p className="text-sm text-red-400">A análise de otimização falhou. Peça ao Nexus para tentar novamente.</p>
      </section>
    );
  }

  if (suggestions.length === 0) {
    return (
      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-white">Sugestões de Otimização</h2>
        <p className="text-sm text-white/50">Nenhuma sugestão gerada. A conta pode estar bem otimizada ou sem dados suficientes.</p>
      </section>
    );
  }

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-lg font-semibold text-white">Sugestões de Otimização</h2>
        <span className="rounded border border-cyan-400/30 bg-cyan-500/10 px-2 py-1 font-mono text-[10px] uppercase tracking-[0.12em] text-cyan-300">
          {suggestions.length} sugestão{suggestions.length !== 1 ? "ões" : ""}
        </span>
      </div>

      <p className="text-xs text-white/40">
        Selecione as sugestões que deseja aprovar e clique em Aplicar.
      </p>

      <ul className="space-y-2">
        {suggestions.map((s) => {
          const isChecked = selected.has(s.id);
          return (
            <li
              key={s.id}
              onClick={() => { setState("idle"); toggleSuggestion(s.id); }}
              className={`tech-panel cursor-pointer rounded-lg px-4 py-3 transition-colors ${
                isChecked ? "border border-cyan-400/30" : "border border-white/5 opacity-60"
              }`}
            >
              <div className="mb-2 flex flex-wrap items-center gap-2">
                <input
                  type="checkbox"
                  checked={isChecked}
                  onChange={() => toggleSuggestion(s.id)}
                  onClick={(e) => e.stopPropagation()}
                  className="h-4 w-4 accent-cyan-400"
                />
                {s.prioridade && (
                  <span
                    className={`rounded border px-2 py-0.5 font-mono text-[10px] uppercase tracking-[0.12em] ${
                      PRIORITY_STYLES[s.prioridade.toLowerCase()] ?? "border-white/10 bg-white/10 text-white/50"
                    }`}
                  >
                    {s.prioridade}
                  </span>
                )}
                {s.tipo_otimizacao && (
                  <span className="font-mono text-[10px] uppercase tracking-[0.1em] text-white/40">
                    {s.tipo_otimizacao}
                  </span>
                )}
                {s.entidade_nome && (
                  <span className="text-xs text-white/40">{s.entidade_nome}</span>
                )}
              </div>
              <p className="text-sm text-white/85">{s.acao}</p>
              {s.impacto_esperado && (
                <p className="mt-1 text-xs text-white/50">→ {s.impacto_esperado}</p>
              )}
              {s.risco && (
                <p className="mt-1 text-xs text-yellow-400/60">⚠ {s.risco}</p>
              )}
            </li>
          );
        })}
      </ul>

      {state === "success" ? (
        <div className="rounded-lg border border-green-400/30 bg-green-500/10 px-4 py-3">
          <p className="text-sm text-green-300">
            Otimizações enfileiradas! Os agents vão aplicar em até um minuto.
          </p>
        </div>
      ) : (
        <div className="flex items-center gap-3">
          <button
            onClick={handleApprove}
            disabled={selected.size === 0 || state === "loading"}
            className="rounded-lg border border-cyan-400/40 bg-cyan-500/15 px-4 py-2 text-sm font-medium text-cyan-200 transition hover:border-cyan-400/70 hover:bg-cyan-500/25 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {state === "loading" ? "Enfileirando…" : `Aplicar ${selected.size} selecionada${selected.size !== 1 ? "s" : ""}`}
          </button>
          {selected.size !== suggestions.length && (
            <button
              onClick={() => setSelected(new Set(suggestions.map((s) => s.id)))}
              className="text-xs text-white/40 hover:text-white/70"
            >
              Selecionar todas
            </button>
          )}
          {state === "error" && (
            <p className="text-sm text-red-400">{errorMsg}</p>
          )}
        </div>
      )}
    </section>
  );
}

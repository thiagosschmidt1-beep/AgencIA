import { describe, it, expect, vi, beforeEach } from "vitest";

// --- hoisted mocks (referenced inside vi.mock factories) ---

const { createMock, recordedCalls } = vi.hoisted(() => ({
  createMock: vi.fn(),
  recordedCalls: [] as Array<{ messages: unknown[] }>,
}));

const { loadMemory, appendExchange } = vi.hoisted(() => ({
  loadMemory: vi.fn(async () => [] as Array<{ role: string; content: string }>),
  appendExchange: vi.fn(async () => {}),
}));

const { runTool } = vi.hoisted(() => ({
  runTool: vi.fn(async (): Promise<unknown> => ({ ok: true, note: "dados de teste" })),
}));

vi.mock("@anthropic-ai/sdk", () => ({
  default: class {
    messages = {
      create: async (args: { messages: unknown[] }) => {
        recordedCalls.push(args);
        return createMock(args);
      },
    };
  },
}));
vi.mock("@/lib/env", () => ({ env: { anthropicApiKey: () => "test-key" } }));
vi.mock("@/lib/nexus/tools", () => ({
  toolSpecs: [],
  runTool,
}));
vi.mock("@/lib/nexus/memory", () => ({ loadMemory, appendExchange }));

import { runChat } from "@/lib/nexus/chat";

const SESSION = "session-test-1";

function textTurn(text: string) {
  return { stop_reason: "end_turn", content: [{ type: "text", text }] };
}
function toolTurn(id: string, name: string, input: Record<string, unknown>) {
  return { stop_reason: "tool_use", content: [{ type: "tool_use", id, name, input }] };
}

beforeEach(() => {
  vi.clearAllMocks();
  recordedCalls.length = 0;
});

describe("runChat — plain reply", () => {
  it("returns the text reply and persists the exchange", async () => {
    createMock.mockResolvedValueOnce(textTurn("Temos um cliente: cliente-exemplo."));

    const result = await runChat(SESSION, "quais clientes temos?");

    expect(result.kind).toBe("reply");
    expect(result.reply).toBe("Temos um cliente: cliente-exemplo.");
    expect(appendExchange).toHaveBeenCalledTimes(1);
    expect((appendExchange.mock.calls[0] as unknown[] | undefined)?.[1]).toBe("quais clientes temos?");
  });
});

describe("runChat — tool loop", () => {
  it("runs a data tool and feeds the result back to the model", async () => {
    createMock
      .mockResolvedValueOnce(toolTurn("tu_ov", "get_client_overview", { client_slug: "cliente-exemplo" }))
      .mockResolvedValueOnce(textTurn("O cliente tem duas campanhas pausadas."));

    const result = await runChat(SESSION, "como está o cliente exemplo?");

    expect(runTool).toHaveBeenCalledWith("get_client_overview", { client_slug: "cliente-exemplo" });
    expect(result.reply).toBe("O cliente tem duas campanhas pausadas.");
    expect(result.usedTools).toEqual(["get_client_overview"]);

    // The second model call must carry the tool_result for tu_ov.
    const secondCall = recordedCalls.at(-1)!;
    const lastMsg = secondCall.messages.at(-1) as { role: string; content: Array<Record<string, unknown>> };
    expect(lastMsg.role).toBe("user");
    expect(lastMsg.content[0]?.tool_use_id).toBe("tu_ov");
  });
});

describe("runChat — agent trigger metadata", () => {
  it("exposes a trigger when a Nexus write tool enqueues a job", async () => {
    runTool.mockResolvedValueOnce({
      enqueued: true,
      job_id: "job-1",
      skill: "create-traffic-cliente-exemplo-campaign",
      kind: "create",
      client_slug: "cliente-exemplo",
      queued_at: "2026-06-01T13:00:00.000Z",
    });
    createMock
      .mockResolvedValueOnce(
        toolTurn("tu_create", "request_campaign_creation", { client_slug: "cliente-exemplo", confirm: true }),
      )
      .mockResolvedValueOnce(textTurn("Pedido enfileirado."));

    const result = await runChat(SESSION, "sim, pode criar");

    expect(result.kind).toBe("reply");
    expect(result.agentTriggers).toEqual([
      {
        jobId: "job-1",
        skill: "create-traffic-cliente-exemplo-campaign",
        kind: "create",
        clientSlug: "cliente-exemplo",
        queuedAt: "2026-06-01T13:00:00.000Z",
        source: "nexus",
      },
    ]);
  });

  it("does not expose a trigger when enqueue is rejected", async () => {
    runTool.mockResolvedValueOnce({ enqueued: false, reason: "já existe um pedido em andamento" });
    createMock
      .mockResolvedValueOnce(
        toolTurn("tu_create", "request_campaign_creation", { client_slug: "cliente-exemplo", confirm: true }),
      )
      .mockResolvedValueOnce(textTurn("Já existe um pedido em andamento."));

    const result = await runChat(SESSION, "sim, pode criar");

    expect(result.kind).toBe("reply");
    expect(result.agentTriggers).toEqual([]);
  });
});

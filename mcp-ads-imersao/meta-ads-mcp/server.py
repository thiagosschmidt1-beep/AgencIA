"""
MCP de Meta Ads — versão didática (single-tenant, System User Token).

Roda de dois jeitos, com o MESMO arquivo:
  - stdio (local):   python server.py
  - HTTP (Vercel):   api/index.py importa o objeto `mcp` daqui

Nunca use print() aqui: no transporte stdio o stdout é o canal do protocolo.
Se precisar logar, use logging (que vai para stderr) ou print(..., file=sys.stderr).
"""

from __future__ import annotations

import os
from typing import Any

from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env.local")

import httpx
from fastmcp import FastMCP

# A versão da Graph API é fixada de propósito. Chamada sem versão explícita cai
# no "default" da conta, que não é necessariamente o mais recente.
GRAPH_VERSION = os.getenv("META_GRAPH_VERSION", "v26.0")
GRAPH = f"https://graph.facebook.com/{GRAPH_VERSION}"

def _auth():
    """Porteiro do servidor HTTP.

    Sem MCP_AUTH_TOKEN definido, o servidor fica aberto — aceitável no stdio local,
    inaceitável numa URL pública. Com o token definido, o cliente precisa mandar
    o header Authorization: Bearer <token>.
    """
    token = os.getenv("MCP_AUTH_TOKEN")
    if not token:
        return None
    from fastmcp.server.auth import StaticTokenVerifier

    return StaticTokenVerifier(
        tokens={token: {"sub": "dono-da-conta", "client_id": "meta-ads-mcp"}}
    )


mcp = FastMCP(
    name="Meta Ads MCP",
    instructions=(
        "Ferramentas de leitura e escrita da Meta Marketing API para UMA conta de "
        "anúncios. IDs de conta usam o prefixo act_ (ex: act_1234567890). "
        "Toda campanha criada por este servidor nasce PAUSED."
    ),
    auth=_auth(),
)


def _token() -> str:
    token = os.getenv("META_ACCESS_TOKEN")
    if not token:
        raise RuntimeError(
            "META_ACCESS_TOKEN não configurado. "
            "Crie um System User Token no Business Manager e coloque no .env "
            "(local) ou nas Environment Variables do projeto (Vercel)."
        )
    return token


async def _request(method: str, path: str, params: dict | None = None) -> dict[str, Any]:
    """Chamada única à Graph API. Devolve o erro da Meta em vez de estourar exceção,
    para o modelo conseguir ler a mensagem e se corrigir sozinho."""
    payload = dict(params or {})
    payload["access_token"] = _token()

    async with httpx.AsyncClient(timeout=60) as client:
        if method == "GET":
            response = await client.get(f"{GRAPH}/{path}", params=payload)
        else:
            response = await client.post(f"{GRAPH}/{path}", data=payload)

    try:
        body = response.json()
    except ValueError:
        return {"erro": "resposta não-JSON da Meta", "http_status": response.status_code}

    if response.status_code >= 400:
        erro = body.get("error", {})
        return {
            "erro": erro.get("message", "erro desconhecido"),
            "codigo": erro.get("code"),
            "subcodigo": erro.get("error_subcode"),
            "tipo": erro.get("type"),
            "http_status": response.status_code,
        }
    return body


@mcp.tool
async def listar_contas(business_id: str) -> dict:
    """Lista as contas de anúncio de um Business Manager.

    business_id: ID numérico do BM (Configurações do Negócio > Informações do negócio).
    """
    return await _request(
        "GET",
        f"{business_id}/owned_ad_accounts",
        {"fields": "id,name,account_status,currency,timezone_name,amount_spent", "limit": 100},
    )


@mcp.tool
async def listar_campanhas(account_id: str, limite: int = 25) -> dict:
    """Lista as campanhas de uma conta de anúncios.

    account_id: no formato act_1234567890.
    """
    return await _request(
        "GET",
        f"{account_id}/campaigns",
        {
            "fields": "id,name,status,effective_status,objective,daily_budget,lifetime_budget,created_time",
            "limit": limite,
        },
    )


@mcp.tool
async def metricas(
    account_id: str,
    periodo: str = "last_7d",
    nivel: str = "campaign",
) -> dict:
    """Métricas de performance da conta: gasto, impressões, cliques, CTR, CPC, ações e ROAS.

    account_id: no formato act_1234567890.
    periodo: today, yesterday, last_7d, last_14d, last_30d, this_month, last_month, maximum.
    nivel: account, campaign, adset ou ad.
    """
    return await _request(
        "GET",
        f"{account_id}/insights",
        {
            "fields": (
                "campaign_name,adset_name,ad_name,spend,impressions,clicks,ctr,cpc,cpm,"
                "actions,cost_per_action_type,purchase_roas"
            ),
            "date_preset": periodo,
            "level": nivel,
            "limit": 100,
        },
    )


@mcp.tool
async def criar_campanha_pausada(
    account_id: str,
    nome: str,
    objetivo: str = "OUTCOME_SALES",
    orcamento_diario_centavos: int = 2000,
) -> dict:
    """Cria uma campanha NOVA já PAUSADA (nunca sobe no ar sozinha).

    account_id: no formato act_1234567890.
    objetivo: OUTCOME_SALES, OUTCOME_LEADS, OUTCOME_TRAFFIC, OUTCOME_ENGAGEMENT,
              OUTCOME_AWARENESS ou OUTCOME_APP_PROMOTION.
    orcamento_diario_centavos: 2000 = R$ 20,00/dia.
    """
    return await _request(
        "POST",
        f"{account_id}/campaigns",
        {
            "name": nome,
            "objective": objetivo,
            "status": "PAUSED",
            "daily_budget": orcamento_diario_centavos,
        },
    )


@mcp.tool
async def mudar_status_campanha(campaign_id: str, status: str) -> dict:
    """Ativa ou pausa uma campanha existente. status: ACTIVE ou PAUSED."""
    status = status.upper()
    if status not in {"ACTIVE", "PAUSED"}:
        return {"erro": "status deve ser ACTIVE ou PAUSED"}
    return await _request("POST", campaign_id, {"status": status})


if __name__ == "__main__":
    # Transporte stdio — é assim que o Claude Code sobe o servidor localmente.
    mcp.run()

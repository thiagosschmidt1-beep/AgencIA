"""
MCP de Google Ads — versão didática (single-tenant, refresh token OAuth).

Diferente da Meta, o Google não tem "system user token": você precisa de
developer token aprovado + client_id/client_secret + refresh_token. O README
explica como conseguir cada um.

Roda de dois jeitos, com o MESMO arquivo:
  - stdio (local):   python server.py
  - HTTP (Vercel):   api/index.py importa o objeto `mcp` daqui

Este servidor fala REST direto com a API (sem a biblioteca google-ads, que é
pesada demais para serverless). Toda leitura é GAQL.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

# Carrega .env.local quando rodando localmente (stdio ou HTTP local).
# Em produção (Vercel) o arquivo não existe — load_dotenv é no-op.
# override=False: variáveis já definidas no sistema têm precedência.
load_dotenv(Path(__file__).parent / ".env.local")

import httpx
from fastmcp import FastMCP

# Versão fixada de propósito. O Google passou a lançar versão nova por mês e cada
# uma morre em ~6 meses — confira a tabela de sunset antes de trocar:
# https://developers.google.com/google-ads/api/docs/sunset-dates
API_VERSION = os.getenv("GOOGLE_ADS_API_VERSION", "v24")
ADS_API = f"https://googleads.googleapis.com/{API_VERSION}"
OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token"


def _env(nome: str) -> str:
    valor = os.getenv(nome)
    if not valor:
        raise RuntimeError(f"{nome} não configurado. Veja a seção Google Ads do README.")
    return valor


def _auth():
    """Porteiro do servidor HTTP (mesma lógica do MCP da Meta)."""
    token = os.getenv("MCP_AUTH_TOKEN")
    if not token:
        return None
    from fastmcp.server.auth import StaticTokenVerifier

    return StaticTokenVerifier(
        tokens={token: {"sub": "dono-da-conta", "client_id": "google-ads-mcp"}}
    )


mcp = FastMCP(
    name="Google Ads MCP",
    instructions=(
        "Ferramentas de leitura da Google Ads API via GAQL. customer_id é sempre "
        "só dígitos, sem hífen (1234567890, não 123-456-7890). Se a conta for "
        "gerenciada por um MCC, o MCC vai no GOOGLE_ADS_LOGIN_CUSTOMER_ID."
    ),
    auth=_auth(),
)


async def _access_token(client: httpx.AsyncClient) -> str:
    """Troca o refresh token por um access token válido (~1h). Como cada invocação
    serverless é fria, trocamos a cada chamada — simples e suficiente para uso pessoal."""
    response = await client.post(
        OAUTH_TOKEN_URL,
        data={
            "client_id": _env("GOOGLE_ADS_CLIENT_ID"),
            "client_secret": _env("GOOGLE_ADS_CLIENT_SECRET"),
            "refresh_token": _env("GOOGLE_ADS_REFRESH_TOKEN"),
            "grant_type": "refresh_token",
        },
    )
    body = response.json()
    if response.status_code >= 400:
        raise RuntimeError(
            f"falha ao renovar o access token: {body.get('error_description', body)}"
        )
    return body["access_token"]


def _headers(token: str) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "developer-token": _env("GOOGLE_ADS_DEVELOPER_TOKEN"),
        "Content-Type": "application/json",
    }
    login_cid = os.getenv("GOOGLE_ADS_LOGIN_CUSTOMER_ID")
    if login_cid:
        headers["login-customer-id"] = login_cid.replace("-", "")
    return headers


async def _gaql(customer_id: str, query: str, limite_paginas: int = 1) -> dict[str, Any]:
    """Executa uma query GAQL e devolve as linhas. Erros voltam como dado, não exceção."""
    customer_id = customer_id.replace("-", "").strip()
    linhas: list[Any] = []
    page_token: str | None = None

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            token = await _access_token(client)
            headers = _headers(token)

            for _ in range(max(1, limite_paginas)):
                payload: dict[str, Any] = {"query": query}
                if page_token:
                    payload["pageToken"] = page_token

                response = await client.post(
                    f"{ADS_API}/customers/{customer_id}/googleAds:search",
                    headers=headers,
                    json=payload,
                )
                body = response.json()

                if response.status_code >= 400:
                    erro = body.get("error", {})
                    return {
                        "erro": erro.get("message", "erro desconhecido"),
                        "status": erro.get("status"),
                        "http_status": response.status_code,
                        "detalhes": erro.get("details"),
                    }

                linhas.extend(body.get("results", []))
                page_token = body.get("nextPageToken")
                if not page_token:
                    break
    except RuntimeError as exc:
        return {"erro": str(exc)}

    return {"customer_id": customer_id, "total_linhas": len(linhas), "linhas": linhas}


@mcp.tool
async def listar_contas_acessiveis() -> dict:
    """Lista os customer IDs que o refresh token configurado consegue acessar.

    É o primeiro comando a rodar depois de configurar o .env — se ele funciona,
    as credenciais estão corretas.
    """
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            token = await _access_token(client)
            response = await client.get(
                f"{ADS_API}/customers:listAccessibleCustomers", headers=_headers(token)
            )
    except RuntimeError as exc:
        return {"erro": str(exc)}

    body = response.json()
    if response.status_code >= 400:
        erro = body.get("error", {})
        return {"erro": erro.get("message", body), "http_status": response.status_code}

    recursos = body.get("resourceNames", [])
    return {"contas": [r.split("/")[-1] for r in recursos]}


@mcp.tool
async def listar_campanhas(customer_id: str, limite: int = 50) -> dict:
    """Lista campanhas da conta com status, tipo, orçamento e estratégia de lance.

    customer_id: só dígitos, sem hífen.
    """
    query = f"""
        SELECT campaign.id, campaign.name, campaign.status,
               campaign.advertising_channel_type, campaign.bidding_strategy_type,
               campaign_budget.amount_micros
        FROM campaign
        WHERE campaign.status != 'REMOVED'
        ORDER BY campaign.name
        LIMIT {int(limite)}
    """
    return await _gaql(customer_id, query)


@mcp.tool
async def metricas(customer_id: str, periodo: str = "LAST_7_DAYS") -> dict:
    """Métricas por campanha: impressões, cliques, CTR, CPC médio, custo e conversões.

    customer_id: só dígitos, sem hífen.
    periodo: TODAY, YESTERDAY, LAST_7_DAYS, LAST_14_DAYS, LAST_30_DAYS,
             THIS_MONTH, LAST_MONTH.
    """
    periodo = periodo.upper()
    query = f"""
        SELECT campaign.id, campaign.name, campaign.status,
               metrics.impressions, metrics.clicks, metrics.ctr,
               metrics.average_cpc, metrics.cost_micros,
               metrics.conversions, metrics.cost_per_conversion,
               metrics.conversions_value
        FROM campaign
        WHERE segments.date DURING {periodo}
          AND campaign.status != 'REMOVED'
        ORDER BY metrics.cost_micros DESC
    """
    return await _gaql(customer_id, query)


@mcp.tool
async def termos_de_busca(customer_id: str, periodo: str = "LAST_7_DAYS", limite: int = 100) -> dict:
    """Relatório de termos de busca: o que as pessoas realmente digitaram.

    É onde se acha desperdício para virar palavra-chave negativa.
    """
    periodo = periodo.upper()
    query = f"""
        SELECT search_term_view.search_term, campaign.name, ad_group.name,
               metrics.impressions, metrics.clicks, metrics.cost_micros,
               metrics.conversions
        FROM search_term_view
        WHERE segments.date DURING {periodo}
        ORDER BY metrics.cost_micros DESC
        LIMIT {int(limite)}
    """
    return await _gaql(customer_id, query)


@mcp.tool
async def consulta_gaql(customer_id: str, query: str) -> dict:
    """Executa uma query GAQL arbitrária (somente leitura).

    Use quando as tools prontas não cobrirem o que você precisa.
    Referência: https://developers.google.com/google-ads/api/docs/query/overview
    """
    return await _gaql(customer_id, query, limite_paginas=3)


if __name__ == "__main__":
    mcp.run()

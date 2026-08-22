"""
Entrypoint HTTP (Vercel).

A Vercel procura um objeto ASGI chamado `app` neste arquivo. O vercel.json
roteia todas as requisições para cá, então os endpoints ficam em:
https://SEU-PROJETO.vercel.app/mcp   (MCP)
https://SEU-PROJETO.vercel.app/health (health check)

Duas coisas aqui não são opcionais:

1. stateless_http=True — cada request pode cair numa instância diferente da
   Vercel. Sem isso, o request 2 não acha a sessão criada no request 1.

2. MCP_AUTH_TOKEN (definido no server.py) — este servidor é uma URL pública com
   um token de conta de anúncios dentro. Sem porteiro, quem descobrir a URL
   mexe no orçamento da sua conta.
"""

from __future__ import annotations

import sys
from pathlib import Path

from starlette.responses import JSONResponse

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from server import mcp  # noqa: E402


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    return JSONResponse({"status": "ok", "servidor": "meta-ads-mcp"})


app = mcp.http_app(path="/mcp", stateless_http=True)

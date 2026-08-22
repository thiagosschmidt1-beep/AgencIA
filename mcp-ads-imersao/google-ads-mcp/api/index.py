"""
Entrypoint HTTP (Vercel) do MCP de Google Ads.
Mesma estrutura do MCP da Meta — ver comentários em ../../meta-ads-mcp/api/index.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from starlette.responses import JSONResponse

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from server import mcp  # noqa: E402


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    return JSONResponse({"status": "ok", "servidor": "google-ads-mcp"})


app = mcp.http_app(path="/mcp", stateless_http=True)

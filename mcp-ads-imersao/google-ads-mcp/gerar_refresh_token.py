"""
Gera o GOOGLE_ADS_REFRESH_TOKEN — rode UMA vez, na sua máquina.

Pré-requisito: no Google Cloud Console, crie uma credencial OAuth do tipo
"Aplicativo da Web" e adicione EXATAMENTE este URI de redirecionamento:

    http://localhost:8080/

Uso:
    python gerar_refresh_token.py

O script abre o navegador, você faz login com a conta que TEM ACESSO ao
Google Ads, e ele imprime o refresh token no final. Cole no .env e nunca
mais precise repetir (o refresh token não expira, salvo revogação).

Não precisa de nenhuma biblioteca além do que já está no requirements.txt.
"""

from __future__ import annotations

import http.server
import socketserver
import urllib.parse
import webbrowser

import httpx

REDIRECT_URI = "http://localhost:8080/"
SCOPE = "https://www.googleapis.com/auth/adwords"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"

codigo_recebido: dict[str, str] = {}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        if "code" in params:
            codigo_recebido["code"] = params["code"][0]
            corpo = "<h2>Pronto. Pode fechar esta aba e voltar para o terminal.</h2>"
        else:
            corpo = f"<h2>Erro: {params.get('error', ['desconhecido'])[0]}</h2>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(corpo.encode("utf-8"))

    def log_message(self, *args):  # silencia o log do http.server
        return


def main() -> None:
    client_id = input("GOOGLE_ADS_CLIENT_ID: ").strip()
    client_secret = input("GOOGLE_ADS_CLIENT_SECRET: ").strip()

    params = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "redirect_uri": REDIRECT_URI,
            "response_type": "code",
            "scope": SCOPE,
            "access_type": "offline",
            "prompt": "consent",
        }
    )
    url = f"{AUTH_URL}?{params}"

    print("\nAbrindo o navegador. Se não abrir, cole esta URL:\n")
    print(url, "\n")
    webbrowser.open(url)

    with socketserver.TCPServer(("localhost", 8080), Handler) as httpd:
        print("Aguardando a autorização em http://localhost:8080/ ...")
        while "code" not in codigo_recebido:
            httpd.handle_request()

    resposta = httpx.post(
        TOKEN_URL,
        data={
            "code": codigo_recebido["code"],
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": REDIRECT_URI,
            "grant_type": "authorization_code",
        },
        timeout=30,
    )
    dados = resposta.json()

    if "refresh_token" not in dados:
        print("\nNão veio refresh token. Resposta do Google:")
        print(dados)
        print(
            "\nDica: se você já autorizou este app antes, revogue o acesso em "
            "https://myaccount.google.com/permissions e rode de novo."
        )
        return

    print("\n" + "=" * 60)
    print("GOOGLE_ADS_REFRESH_TOKEN=" + dados["refresh_token"])
    print("=" * 60)
    print("\nCole a linha acima no seu .env.")


if __name__ == "__main__":
    main()

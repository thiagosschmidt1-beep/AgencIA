# MCPs de Meta Ads e Google Ads — versão didática

Dois servidores MCP independentes, em Python, que você roda local (stdio) ou publica na Vercel (HTTP).
São **single-tenant**: cada aluno usa nas próprias contas, com as próprias credenciais.

```
meta-ads-mcp/     -> 5 tools da Meta Marketing API   (System User Token)
google-ads-mcp/   -> 5 tools da Google Ads API       (OAuth refresh token)
```

Cada pasta é um projeto separado, com seu próprio `requirements.txt` e seu próprio deploy.
Não junte os dois no mesmo servidor: as credenciais são de naturezas diferentes e um problema
em um não pode derrubar o outro.

---

## Pré-requisitos

- Python 3.10 ou superior
- Claude Code (ou outro cliente MCP)
- Conta no Vercel, se for publicar online (opcional — dá para usar tudo em stdio local)
- Uma conta de anúncios que você administre (pode ser de teste)

---

## Parte 1 — MCP da Meta Ads

### 1.1 Pegar o System User Token

O System User Token é o caminho certo aqui: não expira, não depende de um humano logado,
e é o mesmo token que você vai usar depois num agente rodando em cron.

1. Abra o **Business Manager** → Configurações do Negócio
2. **Usuários → Usuários do sistema** → Adicionar → tipo *Admin*
3. Em **Ativos**, atribua a conta de anúncios ao usuário do sistema com acesso total
4. Clique em **Gerar novo token**, escolha o app e marque as permissões:
   - `ads_read` (leitura de métricas)
   - `ads_management` (criar e editar campanhas)
   - `business_management` (listar contas do BM)
5. Copie o token — ele só aparece uma vez

Anote também o **ID do Business Manager** (Configurações do Negócio → Informações do negócio)
e o **ID da conta de anúncios** (aparece no Gerenciador de Anúncios, formato `act_1234567890`).

### 1.2 Instalar e rodar local (stdio)

```bash
cd meta-ads-mcp
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env               # e edite o .env com seu token
```

Teste se o servidor sobe (Ctrl+C para sair — ele fica em silêncio esperando o cliente, isso é normal):

```bash
python server.py
```

### 1.3 Conectar no Claude Code

Da pasta onde você quer usar o MCP:

```bash
claude mcp add meta-ads \
  --env META_ACCESS_TOKEN=SEU_TOKEN_AQUI \
  -- /caminho/completo/para/meta-ads-mcp/.venv/bin/python /caminho/completo/para/meta-ads-mcp/server.py
```

Use **caminhos absolutos** nos dois lugares. Depois abra o Claude Code e rode `/mcp` para
conferir que apareceu. Teste com: *"liste as campanhas da conta act_XXX dos últimos 7 dias"*.

### 1.4 Publicar na Vercel (opcional)

```bash
cd meta-ads-mcp
npm i -g vercel
vercel                             # primeira vez: cria o projeto
```

No painel do projeto, em **Settings → Environment Variables**, adicione:

| Variável | Valor |
|---|---|
| `META_ACCESS_TOKEN` | seu system user token |
| `MCP_AUTH_TOKEN` | uma senha longa gerada por você (ver abaixo) |

Gere o `MCP_AUTH_TOKEN` com:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Depois:

```bash
vercel --prod
```

Confira que subiu: `https://SEU-PROJETO.vercel.app/health` deve responder `{"status":"ok"}`.

Conecte no Claude Code:

```bash
claude mcp add --transport http meta-ads-online \
  https://SEU-PROJETO.vercel.app/mcp \
  --header "Authorization: Bearer SEU_MCP_AUTH_TOKEN"
```

### 1.5 Tools disponíveis

| Tool | O que faz |
|---|---|
| `listar_contas` | Contas de anúncio de um Business Manager |
| `listar_campanhas` | Campanhas da conta, com status e orçamento |
| `metricas` | Gasto, impressões, cliques, CTR, CPC, ações e ROAS |
| `criar_campanha_pausada` | Cria campanha nova — sempre `PAUSED` |
| `mudar_status_campanha` | Ativa ou pausa uma campanha existente |

---

## Parte 2 — MCP do Google Ads

A configuração aqui é mais chata que a da Meta e **não termina no mesmo dia**: o developer token
precisa de aprovação do Google. Comece por ela.

### 2.1 Developer token

1. Entre na sua conta **MCC** (conta de administrador do Google Ads)
2. **Ferramentas e configurações → Configuração → Central de API**
3. Solicite o developer token e preencha o formulário

Você recebe um token com **acesso de teste** na hora, que só funciona em contas de teste.
Para operar em contas reais precisa do **Basic access**, que leva alguns dias úteis.
Enquanto espera, dá para desenvolver tudo contra uma conta de teste.

### 2.2 Credenciais OAuth

1. No [Google Cloud Console](https://console.cloud.google.com), crie um projeto
2. Ative a **Google Ads API** em APIs e Serviços
3. Em **Credenciais**, crie um *ID do cliente OAuth* do tipo **Aplicativo da Web**
4. Adicione o URI de redirecionamento: `http://localhost:8080/`
5. Anote o **client ID** e o **client secret**

### 2.3 Gerar o refresh token

```bash
cd google-ads-mcp
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python gerar_refresh_token.py
```

O script abre o navegador, você autoriza com a conta que tem acesso ao Google Ads,
e ele imprime o `GOOGLE_ADS_REFRESH_TOKEN` no terminal.

### 2.4 Configurar

```bash
cp .env.example .env
```

Preencha:

| Variável | Onde encontrar |
|---|---|
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Central de API do MCC |
| `GOOGLE_ADS_CLIENT_ID` | Google Cloud Console → Credenciais |
| `GOOGLE_ADS_CLIENT_SECRET` | Google Cloud Console → Credenciais |
| `GOOGLE_ADS_REFRESH_TOKEN` | saída do `gerar_refresh_token.py` |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | ID do MCC, só dígitos, sem hífen |

### 2.5 Conectar e testar

```bash
claude mcp add google-ads \
  --env GOOGLE_ADS_DEVELOPER_TOKEN=... \
  --env GOOGLE_ADS_CLIENT_ID=... \
  --env GOOGLE_ADS_CLIENT_SECRET=... \
  --env GOOGLE_ADS_REFRESH_TOKEN=... \
  --env GOOGLE_ADS_LOGIN_CUSTOMER_ID=... \
  -- /caminho/completo/google-ads-mcp/.venv/bin/python /caminho/completo/google-ads-mcp/server.py
```

Primeiro comando a testar: *"liste as contas acessíveis do Google Ads"*. Se isso funciona,
as credenciais estão certas e o resto é consequência.

O deploy na Vercel é idêntico ao da Meta (seção 1.4), trocando as variáveis de ambiente.

### 2.6 Tools disponíveis

| Tool | O que faz |
|---|---|
| `listar_contas_acessiveis` | Customer IDs que suas credenciais alcançam |
| `listar_campanhas` | Campanhas com status, tipo e orçamento |
| `metricas` | Impressões, cliques, CTR, CPC, custo e conversões |
| `termos_de_busca` | O que as pessoas digitaram — onde mora o desperdício |
| `consulta_gaql` | Query GAQL livre, para o que as outras tools não cobrem |

---

## Segurança — leia antes de publicar

Um MCP publicado na Vercel é **uma URL pública com o token da sua conta de anúncios dentro**.
Sem porteiro, quem descobrir a URL mexe no seu orçamento.

- `MCP_AUTH_TOKEN` **sempre** definido em produção. Sem ele, o servidor sobe aberto.
- O `.env` está no `.gitignore`. Não tire de lá, e não commite token nenhum.
- Se vazar um token: na Meta, revogue o system user token no Business Manager;
  no Google, revogue o acesso em `myaccount.google.com/permissions`.
- Trate escrita com respeito: `criar_campanha_pausada` nasce `PAUSED` de propósito.
  Se você mudar isso, o agente passa a poder gastar seu dinheiro sozinho.

---

## Manutenção — as duas APIs se movem

Ambas as versões de API estão fixadas no código, em uma constante no topo de cada `server.py`:

- **Meta**: `META_GRAPH_VERSION` (default `v26.0`). A v26.0 entrou em vigor em 29/07/2026.
  Versões novas saem a cada ~6 meses e as antigas param de responder ~2 anos depois.
- **Google**: `GOOGLE_ADS_API_VERSION` (default `v24`). O Google passou a lançar versão
  **por mês** em 2026 e cada uma vive ~6 meses — a v21 morre em 05/08/2026. Confira a
  [tabela de sunset](https://developers.google.com/google-ads/api/docs/sunset-dates)
  antes de assumir que a sua ainda funciona.

Quando uma versão morre, a chamada não degrada: ela simplesmente falha. Se as métricas
zerarem do nada, a primeira suspeita é essa.

---

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| MCP não aparece no `/mcp` do Claude Code | caminho relativo no `claude mcp add` — use absoluto |
| Servidor stdio cai com erro genérico | algum `print()` no stdout; no stdio o stdout é o protocolo, log vai pro stderr |
| `Invalid OAuth access token` (Meta) | token errado, expirado ou sem a permissão necessária |
| `401` no servidor da Vercel | falta o header `Authorization: Bearer` com o `MCP_AUTH_TOKEN` |
| Erros de sessão intermitentes na Vercel | `stateless_http=True` foi removido do `api/index.py` |
| `DEVELOPER_TOKEN_NOT_APPROVED` | developer token ainda em acesso de teste — use conta de teste |
| `USER_PERMISSION_DENIED` (Google) | falta o `GOOGLE_ADS_LOGIN_CUSTOMER_ID` do MCC |

---

## Como isso funciona por dentro

O mesmo `server.py` serve os dois transportes:

- **stdio**: `mcp.run()` no final do arquivo. O cliente sobe o processo e conversa por stdin/stdout.
- **HTTP**: `api/index.py` importa o objeto `mcp` e expõe `mcp.http_app(path="/mcp", stateless_http=True)`.

`stateless_http=True` não é detalhe: na Vercel cada request pode cair numa instância diferente,
e sessão guardada em memória não sobrevive a isso.

O `vercel.json` reescreve todas as rotas para `api/index`, o que faz o endpoint final ser
`/mcp` em vez de `/api/index`.

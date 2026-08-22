# SPEC: Carregamento de `.env.local` no MCP Google Ads

## 1. Problema

O arquivo `.env.local` existe com todas as credenciais preenchidas, mas o servidor **nunca as lê**. Python não carrega arquivos `.env` automaticamente (isso é convenção exclusiva do Next.js/Node.js). O `server.py` usa `os.getenv()` puro, sem nenhuma chamada a `load_dotenv()`.

### Gap Analysis

| Item | Estado atual | Estado esperado |
|---|---|---|
| Carregamento do `.env.local` | ❌ Nunca acontece | ✅ Carregado antes de qualquer `os.getenv()` |
| Dependência `python-dotenv` | ❌ Ausente em `requirements.txt` | ✅ Listada e instalada |
| `.env.local` no `.gitignore` | ❌ Credentials expostas | ✅ Excluído do controle de versão |
| Variáveis disponíveis em runtime | ❌ `None` → `RuntimeError` | ✅ Populadas do arquivo |

### Cadeia de falha atual

```
python server.py
  └─ import server
       ├─ API_VERSION = os.getenv("GOOGLE_ADS_API_VERSION", "v24")  → "v24" (fallback)
       ├─ _auth() → os.getenv("MCP_AUTH_TOKEN")                    → None
       └─ FastMCP(auth=None)  ← OK até aqui
  └─ mcp.run()  →  usuário chama listar_contas_acessiveis()
       └─ _access_token()
            └─ _env("GOOGLE_ADS_CLIENT_ID")
                 └─ os.getenv("GOOGLE_ADS_CLIENT_ID") → None
                      └─ RuntimeError: "GOOGLE_ADS_CLIENT_ID não configurado"
```

---

## 2. Especificação de Comportamento Esperado

### 2.1 Regra de Carregamento

```
SE .env.local existe na pasta do servidor:
    → carregar variáveis para os.environ ANTES de qualquer os.getenv()
    → variáveis já definidas no sistema NÃO são sobrescritas (override=False)
SENÃO:
    → no-op (Vercel usa variáveis de ambiente do painel, não precisa de arquivo)
```

### 2.2 Prioridade de Variáveis (maior → menor)

```
1. Variáveis do sistema operacional / Vercel environment
2. .env.local  (desenvolvimento local)
3. Fallbacks hard-coded (ex.: API_VERSION = "v24")
```

### 2.3 Onde o carregamento deve ocorrer

- **`server.py` linha 1** (antes de qualquer `import os` + `os.getenv`) — é o ponto mais cedo possível
- `_auth()` e `API_VERSION` são chamados em tempo de importação de módulo (não dentro de `if __name__ == "__main__"`), então o `load_dotenv` PRECISA estar antes deles

---

## 3. Plano de Implementação

### Passo 1 — Adicionar `python-dotenv` ao `requirements.txt`

```diff
 fastmcp==3.4.5
 httpx==0.28.1
+python-dotenv==1.0.1
```

**Por quê versão fixada?** Mantém reprodutibilidade; `1.0.1` é a versão estável mais recente.

---

### Passo 2 — Carregar `.env.local` em `server.py`

Inserir logo no topo, antes de `import os`:

```python
from pathlib import Path
from dotenv import load_dotenv

# Carrega .env.local quando rodando localmente (stdio ou HTTP local).
# Em produção (Vercel) o arquivo não existe — load_dotenv é no-op.
load_dotenv(Path(__file__).parent / ".env.local")
```

**Por que `Path(__file__).parent`?**
Garante que o caminho é relativo ao `server.py`, não ao diretório de trabalho corrente. Evita falha quando o servidor é iniciado de outro diretório (ex.: Claude Desktop que inicia `python /caminho/absoluto/server.py`).

**Por que não `override=True`?**
Deixar o padrão `override=False` significa que se a variável já estiver no ambiente do processo (ex.: definida pelo CI ou pelo painel da Vercel), ela tem precedência. O `.env.local` só preenche o que está faltando.

---

### Passo 3 — Adicionar `.env.local` ao `.gitignore`

```diff
 .env
+.env.local
 .venv/
 venv/
 __pycache__/
 *.pyc
 .vercel
 .DS_Store
```

**Por que apenas `.env.local` e não `*.env`?**
`.env.example` DEVE permanecer rastreado (é o template para novos desenvolvedores).

---

### Passo 4 — Corrigir comentário inline em `.env.local`

A linha:
```
NGROK_ENABLED=true # Altere para false quando não quiser usar ngrok
```

O `python-dotenv` suporta comentários inline precedidos de espaço, então o valor será parseado corretamente como `true`. Porém, por clareza e compatibilidade com outras ferramentas, mover o comentário para linha própria:

```
# Altere para false quando não quiser usar ngrok
NGROK_ENABLED=true
```

---

## 4. Critérios de Aceite

### 4.1 Verificação local (stdio)

```bash
# 1. Instalar dependências
pip install -r requirements.txt

# 2. Rodar servidor
python server.py

# Resultado esperado: sem RuntimeError, servidor aguardando conexão MCP
```

### 4.2 Verificação via Python inline

```python
# Antes de rodar server.py, confirmar que as vars são carregadas:
python -c "
from pathlib import Path
from dotenv import load_dotenv
import os
load_dotenv(Path('server.py').parent / '.env.local')
print('CLIENT_ID:', os.getenv('GOOGLE_ADS_CLIENT_ID', 'NÃO CARREGADO'))
print('DEV_TOKEN:', os.getenv('GOOGLE_ADS_DEVELOPER_TOKEN', 'NÃO CARREGADO'))
"
# Resultado esperado: valores reais, não 'NÃO CARREGADO'
```

### 4.3 Verificação de segurança

```bash
git status
# .env.local NÃO deve aparecer em "Changes to be committed" nem em "Untracked files"
```

---

## 5. O que NÃO muda

- Lógica de negócio do `server.py` (tools, GAQL, OAuth flow)
- `api/index.py` — Vercel usa variáveis de ambiente do painel, sem `.env.local`
- `gerar_refresh_token.py` — script standalone que pede credenciais via `input()`
- `.env.example` — permanece rastreado como template

---

## 6. Arquivos modificados

| Arquivo | Tipo de mudança |
|---|---|
| `requirements.txt` | Adicionar `python-dotenv==1.0.1` |
| `server.py` | Adicionar `load_dotenv` no topo |
| `.gitignore` | Adicionar `.env.local` |
| `.env.local` | Corrigir comentário inline (cosmético) |

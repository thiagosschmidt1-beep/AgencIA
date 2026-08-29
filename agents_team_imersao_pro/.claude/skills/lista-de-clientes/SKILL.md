---
name: lista-de-clientes
description: lista que contem das informações de clientes como id da BM, conta de anúncios, página do instagram, URLs, limites de orçamentos diários por campanha etc.
allowed-tools: Read, Bash
---

## Clientes

> BM global: todas as contas pertencem ao mesmo Business Manager (System User Token compartilhado).
> Page IDs e Pixel IDs: preencher quando disponível — necessários para criação de campanhas.
> Orçamento máximo: limite de segurança para criação/ativação automática de campanhas (não é o orçamento real do cliente).

---

### brasdente
Nome: BRASDENTE (clínica odontológica — Caxias do Sul / Canela / Vacaria)
- Ad Account: `act_1069409921363168`
- Facebook Page: `237630539425217`
- Pixel: sem pixel
- Campaign mode: `MESSAGES`
- WhatsApp: `5554816100021`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/brasdente/`
- Observação: 3 praças (Caxias, Canela, Vacaria). Workaround US→BR ativo (ver NOTES.md §10).

---

### bombapatch
Nome: BOMBAPATCH (CAA-01)
- Ad Account: `act_1019769737168473`
- Facebook Page: `1248101841711218`
- Pixel: `868031095930066`
- Campaign mode: `SALES_WEBSITE`
- Landing URL: `https://superbombapatch.com/`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/bombapatch/`

---

### cardsofparadise
Nome: CARDS OF PARADISE
- Ad Account: `act_1054871085321918`
- Facebook Page: `191902200939686`
- Pixel: `1496290931877457`
- Campaign mode: `SALES_WEBSITE`
- Landing URL: `https://www.cardsofparadise.com.br/?view=ecom/home`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/cardsofparadise/`
- Observação (ecommerce): URL padrão é a home da loja. Para criativos de produto específico, usar a URL do produto.

---

### clorin
Nome: CLORIN
- Ad Account: `act_1152309295351651`
- Facebook Page: `162482000465576`
- Pixel: sem pixel
- Campaign mode: `LEADS_NATIVE`
- Lead Form ID: `1599107858097838`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/clorin/`

---

### coutinho
Nome: COUTINHO INCORPORACOES
- Ad Account: `act_583640952921224`
- Facebook Page: `1430003027264010`
- Pixel: sem pixel
- Campaign mode: `AWARENESS`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/coutinho/`

---

### dolcevivere
Nome: DOLCE VIVERE
- Ad Account: `act_1352822116344860`
- Facebook Page: `909887715530875`
- Pixel: sem pixel
- Campaign mode: `LEADS_NATIVE`
- Lead Form Name: `[FORMS - HOME CARE/CASA DE REPOUSO] | [2P] - [INTENÇÃO] [UTM NÃO LEAD]`
- Lead Form ID: buscar em runtime via MCP Meta (`/act_1352822116344860/leadgen_forms`) filtrando pelo nome acima
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/dolcevivere/`

---

### lulibaby
Nome: LULIBABY
- Ad Account: `act_547504311493941`
- Facebook Page: `574395935767200`
- Pixel: `1930466267487579`
- Campaign mode: `SALES_WEBSITE`
- Landing URL: `https://lulibaby.com.br/`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/lulibaby/`
- Observação (ecommerce): a URL padrão é a home. Se o criativo for focado em um produto específico, o agente deve usar a URL do produto em vez da home — buscar a URL correta fazendo scrape ou inferindo pelo contexto do criativo.

---

### originalflex
Nome: ORIGINAL FLEX
- Ad Account: `act_2551619881886028`
- Facebook Page: `828263243707842`
- Pixel: sem pixel
- Campaign mode: `LEADS_NATIVE`
- Lead Form Name: `[1P] - [MODELO DE NEGÓCIO] - [CONDICIONAL]` (criado em 2026-06-11)
- Lead Form ID: buscar em runtime via MCP Meta (`/act_2551619881886028/leadgen_forms`) filtrando pelo nome acima
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/originalflex/`

---

### piemon
Nome: PIEMON ATACAREJO
- Ad Account: `act_147401468324992`
- Facebook Page: `249531511889551`
- Pixel: sem pixel
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/piemon/`
- Observação: cliente com MÚLTIPLOS tipos de campanha — cada cron entry especifica o `campaign_type`:

  **Campanha 1 — Alcance (Branding)**
  - campaign_type: `AWARENESS`

  **Campanha 2 — WhatsApp Vagas de Emprego**
  - campaign_type: `TRAFFIC_WHATSAPP`
  - WhatsApp: `5569840811139`
  - Ângulo de copy: vagas de emprego / trabalhe conosco

  **Campanha 3 — WhatsApp Grupo de Ofertas**
  - campaign_type: `TRAFFIC_WHATSAPP`
  - WhatsApp: `5569999637440`
  - Ângulo de copy: ofertas / promoções do atacarejo

  **Campanha 4 — Tráfego para Instagram**
  - campaign_type: `TRAFFIC_INSTAGRAM`
  - Instagram Handle: `@piemonoficial`
  - Instagram ID: `17841412748212236`

---

### armando
Nome: ARMANDO PRE MOLDADOS
- Ad Account: `act_105700106495046`
- Facebook Page: `1569698796636481`
- Pixel: sem pixel
- Campaign mode: `MESSAGES`
- WhatsApp: `5551365420018`
- Orçamento máximo permitido: R$50,00/dia por campanha
- Materiais: `.claude/materiais-das-empresas/armando/`

---

---

## ⚠️ Contas acessíveis ainda não identificadas

As contas abaixo têm acesso via token mas não foram identificadas com cliente:
- `act_916714127846683` — sem campanhas (conta vazia)
- `act_1438979637476390` — campanha "PROTECTION DAY"
- `act_456567766033972` — campanha "Mercedes-Benz Marketplace"
- `act_1915540668917414` — campanha "UP - MSG - APPLE"
- `act_2886305411620048` — campanha "Post Instagram estética"
- `act_236022798332733` — campanha "V4 Leads LP Nova"
- `act_814449954504620` — campanha "V4 Engajamento MSG"

## ❌ Sem permissão

- `act_1550015673109767` — erro 403 (ads_management/ads_read não concedido)

# Materiais do cliente: `cliente-exemplo`

Esta pasta guarda os **materiais de marca** de um cliente, consumidos pelas skills de
geração de criativos e landing pages (`create-traffic-*`, `create-landing-page-*`,
agente `image-prompt-generator`). `cliente-exemplo` é um **exemplo genérico** — duplique
esta pasta com o slug do seu cliente real e substitua o conteúdo.

> ⚠️ Os arquivos de imagem reais foram removidos deste template. Adicione os seus.
> Mantenha o slug da pasta igual ao `clients.slug` no banco e aos nomes das skills.

## Estrutura esperada

```
cliente-exemplo/
├── logo/
│   ├── logo.png                          # logo do cliente (fundo transparente de preferência)
│   └── foto-do-infoprodutor/
│       └── instrutor.png                 # foto/retrato do infoprodutor (hero dos criativos)
├── produtos/
│   ├── curso-exemplo.json                # brief estruturado do produto (fonte da geração)
│   └── workshop-exemplo.json
├── exemplo-de-ads/                       # prints de anúncios que já performaram (referência de estilo)
├── refs-canonicas/                       # referências visuais canônicas usadas pelo image-prompt-generator
│   ├── 01-logo.png
│   ├── 02-retrato-instrutor.jpg
│   └── 03..06-estilo-*.jpg               # estilos de arte (paleta, composição, mood)
├── mascote/                              # (opcional) mascote da marca
└── hero/                                 # (opcional) artes hero / OG prontas
```

## Briefs de produto (`produtos/<slug>.json`)

Fonte da verdade do conteúdo de geração (ADR 0014). Cada produto listado em
`.claude/skills/lista-de-produtos/SKILL.md` aponta para um destes JSONs. Use
`curso-exemplo.json` / `workshop-exemplo.json` como modelo e troque os placeholders
(`<...>`, "Nome do Instrutor", preços, checkout, cores da marca).

-- Seed: failed_optimizations
-- Dados importados dos JSONs de otimizações fracassadas por cliente.
-- Clientes excluídos: bpure, originalflex (não atendidos).
-- Inserção com ON CONFLICT DO NOTHING para ser idempotente.

insert into public.failed_optimizations
  (id, client_slug, account_id, data_acao, tipo_otimizacao, padrao, severidade, status_atual, entidade, acao_tomada, por_que_nao_deu_certo, recomendacao, custo_do_aprendizado)
values

-- ============================================================
-- BOMBAPATCH
-- ============================================================
(
  'BOM-2026-001', 'bombapatch', 'act_1019769737168473',
  '2026-07-15, 2026-07-21, 2026-07-23',
  'escala_de_orcamento_rapida_demais',
  'escalar_orcamento_sem_ler_cpa',
  'alta',
  'não revertido — orçamento segue em R$ 315,00/dia em 13/08',
  '{"campaign_id":"120246778483930557","nome_campanha":"V4","adset_id":"120246778483920557"}',
  'Três aumentos de orçamento em 8 dias: 15/07 de R$ 185 -> R$ 203 (+9,7%); 21/07 de R$ 203 -> R$ 243 (+19,7%); 23/07 de R$ 243 -> R$ 315 (+29,6%). Total: +70,3% em 8 dias, sendo os dois últimos com apenas 2 dias de leitura entre eles.',
  'O gasto diário subiu 192% e o volume de compras subiu apenas 28%, depois PAROU de subir: entre a janela B (R$ 195/dia) e a janela E (R$ 325/dia) o gasto cresceu 66% e as compras/dia CAÍRAM de 25,0 para 23,9. A partir de ~R$ 200/dia a campanha atingiu teto de volume e todo real adicional virou CPA. O CPA mais que dobrou (R$ 6,01 -> R$ 13,62) e o ROAS caiu 51% (8,91 -> 4,39).',
  'Recuar o orçamento para R$ 200-220/dia (onde a curva de compras saturou com CPA saudável) e ler 5 dias limpos antes de qualquer novo movimento. Regra: máximo +20% por degrau, mínimo 5 dias entre degraus, gate de CPA — se CPA subir mais de 15% em relação ao degrau anterior, volta ao patamar anterior.',
  'Nas janelas D+E (23/07 a 09/08, 18 dias) a campanha gastou R$ 5.601,60. Se tivesse mantido o CPA de R$ 7,83 da janela B, as mesmas 442 compras teriam custado R$ 3.460,86 — diferença de ~R$ 2.140 de mídia a mais para o mesmo resultado.'
),
(
  'BOM-2026-002', 'bombapatch', 'act_1019769737168473',
  'Período completo (campanha ativa e não corrigida em 13/08)',
  'manter_campanha_de_trafego_sem_conversao',
  'trafego_sem_conversao',
  'alta',
  'ATIVA — não corrigido',
  '{"campaign_id":"120246652599440557","nome_campanha":"Tráfego Campanha 100","ad_id":"120246652599450557","nome_anuncio":"Tráfego Anúncio"}',
  'Campanha com objetivo de tráfego mantida ativa em paralelo à campanha de vendas, consumindo entre R$ 58 e R$ 154 por dia.',
  '30 dias, R$ 2.953,33 gastos, ZERO compras atribuídas. CTR altíssimo (chegou a 17,9%) é sintoma clássico de campanha otimizada para clique: o algoritmo entrega para quem clica em tudo, não para quem compra. CTR vem caindo de forma consistente (17,90% -> 8,63%, queda de 52%) — a campanha está fadigando.',
  'Pausar a campanha 120246652599440557. Se o objetivo for aquecer público, o dinheiro rende mais realocado à V4. Regra: nesta conta nenhuma campanha permanece ativa mais de 14 dias com zero compras atribuídas.',
  'R$ 2.953,33 em 30 dias sem uma única venda — 25,6% de todo o investimento da conta no período.'
),
(
  'BOM-2026-003', 'bombapatch', 'act_1019769737168473',
  '2026-08-10',
  'troca_de_lote_inteiro_de_criativos_no_mesmo_dia',
  'trocar_lote_inteiro_de_criativos',
  'media',
  'não revertido — anúncios 1-7 seguem inativos em 13/08',
  '{"campaign_id":"120246778483930557","adset_id":"120246778483920557","ads_desligados":["120246778989450557","120246779140980557","120246779160800557","120246779182940557","120246779257610557","120246779272530557","120246779280580557"],"ads_ativados":["120247790989960557","120247790839220557","120247790859730557","120247790881610557","120247790909300557","120247790951160557"]}',
  'Os 7 anúncios ativos foram pausados e 6 novos criados e ativados na mesma janela de 1 minuto. Zero sobreposição — nenhum criativo antigo ficou rodando com os novos.',
  'Três problemas: (1) pausados anúncios com ROAS muito acima da conta (120246779182940557=10,91; 120246779160800557=16,82; 120246779272530557=21,23) — eram subentregues por falta de verba, não por performance ruim; (2) trocar 100% dos criativos zera o histórico de entrega e reabre a fase de aprendizado; (3) sem nenhum criativo antigo como controle, é impossível comparar.',
  'Reativar 120246779182940557, 120246779160800557 e 120246779272530557 e dar verba mínima real por 5 dias. Regra: trocar criativos em rodadas, no máximo metade do lote por vez, mantendo os vencedores como controle. Nunca pausar anúncio com ROAS acima do ROAS da campanha por "baixa entrega".',
  'Perda de 3 criativos com ROAS entre 10,9 e 21,2 que nunca foram testados com verba de verdade. R$ 893,57 gastos nos 3 dias pós-troca sem gerar conclusão utilizável.'
),
(
  'BOM-2026-004', 'bombapatch', 'act_1019769737168473',
  '2026-08-10 e 2026-07-23 (padrão recorrente)',
  'multiplas_mudancas_no_mesmo_dia',
  'multiplas_variaveis_no_mesmo_dia',
  'media',
  'padrão recorrente — não corrigido',
  '{"campaign_id":"120246778483930557","campaigns_secundarias":["120246164250670557","120246343399400557"]}',
  'Em 23/07 em 2 minutos: pausa de 2 campanhas + aumento de orçamento da V4. Em 10/08 em 1 minuto: 7 anúncios pausados e 6 criados/ativados.',
  'Cada dia dessas mudanças tem 2+ variáveis alteradas simultaneamente, tornando impossível atribuir o efeito. O caso de 23/07 é o mais caro: o ROAS da V4 caiu de 5,61 para 5,01 logo depois e não há como separar quanto é do salto de orçamento e quanto é da perda das campanhas de topo de funil.',
  'Uma variável por vez. Mudança de orçamento e mudança de criativo/estrutura separadas por no mínimo 5 dias. Toda alteração deve ser registrada com data de reavaliação explícita.',
  'Nenhum custo direto de mídia, mas o custo real é não saber qual movimento causou a degradação — levou o orçamento a ficar em R$ 315/dia por 22 dias sem correção.'
),

-- ============================================================
-- CARDSOFPARADISE
-- ============================================================
(
  'COP-2026-001', 'cardsofparadise', 'act_1054871085321918',
  '2026-07-22',
  'pausa_de_conjuntos_sem_motivacao_registrada',
  null,
  'media',
  'pausado',
  '{"campaign_id":"120245779700760194","adset_ids":["120246909097720194","120245779700790194","120245779700740194"],"conjuntos":["Pokemon","Magic","Flash and Blood"]}',
  'Pausados 3 conjuntos de público frio (Pokemon, Magic, Flash and Blood) sem registrar o motivo.',
  'Nenhum motivo documentado. Impossível avaliar se a pausa foi correta ou não — dados de performance não foram cruzados com a decisão.',
  'Antes de pausar qualquer conjunto, registrar o motivo e a métrica que motivou a decisão (CPL, ROAS, CTR, frequência). Sem contexto, o banco de falhas fica sem aprendizado real.',
  null
),

-- ============================================================
-- CLORIN
-- ============================================================
(
  'CLO-2026-001', 'clorin', 'act_1152309295351651',
  '2026-07-28 (pausa) — revertida em 2026-08-04',
  'pausa_de_anuncio_vencedor',
  'pausar_vencedor',
  'alta',
  'revertido',
  '{"campaign_id":"120243998572360273","nome_campanha":"[V4JO] [MOT3] [ONGOING] [MoFu] - FORMS CLORIN 10 MIL A","adset_id":"120250232967000273","ad_id":"120254594545070273","nome_anuncio":"AD05 - Você sabia que pode substituir dezenas de galões"}',
  'Anúncio pausado (Ativo -> Inativo) em 28/07. Revertido por Eduardo Veiga em 04/08.',
  'O anúncio estava com CPL saudável (R$ 7,91) e alto volume de leads (70 em 14 dias — principal gerador da campanha) quando foi pausado. A pausa cortou a entrega por ~1 semana até ser revertida por outra pessoa — sugerindo que não foi decisão alinhada com toda a equipe.',
  'Antes de pausar um anúncio, checar CPL e volume de leads dos últimos 14 dias. Não pausar anúncios com CPL abaixo da média da conta (~R$ 9,26) sem motivo explícito documentado. Se mais de uma pessoa mexe na conta, alinhar pausas de anúncios com bom desempenho antes de executar.',
  'Estimado em ~R$ 150-250 de leads não capturados durante a semana de pausa.'
),
(
  'CLO-2026-002', 'clorin', 'act_1152309295351651',
  '2026-07-30',
  'duplicacao_de_adset_para_testar_criativos',
  null,
  'media',
  'em observação',
  '{"campaign_id":"120253335566210273","nome_campanha":"[V4JO] [MOT2] [ONGOING] - [LEADS EBOOK - CLORIN]","adset_original_id":"120253335566230273","adset_novo_id":"120255150697600273"}',
  'Criado novo adset idêntico em nome/segmentação/orçamento ao original, com 5 novos anúncios REELS. Anúncios fracos do adset original pausados, mas o vencedor (AD01, 120253335871300273) mantido ativo.',
  'O adset novo está custando 30-55% mais por lead que o anúncio vencedor que já rodava no original (CPL R$ 6,35-6,51 no novo vs. R$ 4,11-5,84 no AD01). Duplicar a estrutura dividiu o orçamento/aprendizado em vez de concentrar verba no anúncio mais barato.',
  'Testar criativos novos dentro do MESMO adset do vencedor (como anúncios adicionais) preserva o aprendizado acumulado do Meta e evita reprovações redundantes. Reavaliar em 17/08; se o CPL não convergir para R$ 4-5, pausar os anúncios mais fracos do adset novo.',
  null
),

-- ============================================================
-- COUTINHO
-- ============================================================
(
  'COU-2026-001', 'coutinho', 'act_583640952921224',
  '2026-07-17',
  'subida_de_lote_grande_de_criativos_em_conjunto_unico',
  'subir_lote_grande_em_conjunto_maduro',
  'alta',
  'não revertido',
  '{"campaign_id":"120237380899190111","adset_id":"120250826483050111","ads_criados":["120252055859620111","120252055890820111","120252055936440111","120252056072810111","120252056105150111","120252056196000111","120252056272190111","120252056298710111","120252056316000111"]}',
  'Nove anúncios novos publicados de uma vez (15h44-15h45) dentro do conjunto 120250826483050111, que já tinha criativos maduros. Pares quase idênticos (AD13/AD14, AD15/AD16, AD17/AD18, AD19/AD20) competindo entre si no mesmo leilão.',
  'Injetar 9 criativos de uma vez em conjunto estabilizado forçou o algoritmo a redistribuir orçamento para aprendizado. Com orçamento de ~R$ 184/dia, nenhum dos novos teve verba suficiente para sair da fase de aprendizado, e o vencedor histórico (AD09-Cópia) perdeu 85% da sua entrega. CPL subiu 47,9% (R$ 39,94 -> R$ 59,07).',
  'Não publicar mais de 2 criativos novos por vez no conjunto 120250826483050111 (nem em qualquer conjunto desta conta) enquanto o orçamento da campanha estiver na casa dos R$ 184/dia. Testar criativo novo em conjunto separado ou substituir 1 a 1.',
  'CPL da conta subiu 47,9% por 11 dias: janela antes (R$ 39,94) vs. depois (R$ 59,07), com R$ 2.185,71 gastos no período ruim.'
),
(
  'COU-2026-002', 'coutinho', 'act_583640952921224',
  '2026-07-17 (subida) — pausado só em 2026-08-03, 17 dias depois',
  'criativo_perdedor_mantido_ativo_tempo_demais',
  'manter_criativo_ruim_por_mais_de_7_dias',
  'media',
  'pausado',
  '{"campaign_id":"120237380899190111","adset_id":"120250826483050111","ad_id":"120252056272190111","nome":"AD19 - [FIVE] - Imóvel no endereço"}',
  'AD19 subiu em 17/07 e foi o único do lote a receber verba relevante. Ficou ativo até ser pausado em 03/08.',
  'O criativo teve o pior CTR do lote FIVE (1,11% contra 2,6-3,8% dos vencedores) e mesmo assim recebeu o maior orçamento entre os novos. Levou 17 dias até a pausa; queimou o equivalente a ~5 leads na média da conta (R$ 224 / CPL R$ 39,94).',
  'Não reativar o ad_id 120252056272190111. Regra: criativo com gasto acumulado maior que 2x o CPL alvo e zero/um lead deve ser cortado em até 7 dias.',
  'R$ 225,19 em 30 dias para 2 leads — CPL R$ 112,59 (2,8x pior que a média da conta no período).'
),
(
  'COU-2026-003', 'coutinho', 'act_583640952921224',
  '2026-07-17 (subida) — pausado em 2026-08-03',
  'criativo_zero_conversao_mantido_ativo',
  'criativo_ctr_abaixo_de_1pct_sem_corte_rapido',
  'media',
  'pausado',
  '{"campaign_id":"120237380899190111","adset_id":"120250826483050111","ad_id":"120252056105150111","nome":"AD17 - [AZURE] - Garanta sua unidade"}',
  'AD17 (Azure) ativo de 17/07 a 03/08 sem nunca gerar lead.',
  'CTR de 0,63% — o pior de todos os criativos de formulário da conta (que operam entre 1,4% e 3,8%). O criativo não passou no teste já nos primeiros dias e ainda assim consumiu R$ 99 até ser pausado 17 dias depois.',
  'Não reativar o ad_id 120252056105150111 nem reutilizar esse ângulo/criativo. Referência: nesta conta, CTR abaixo de 1,0% em criativo de formulário nunca gerou lead.',
  'R$ 100,56 em 30 dias para 0 leads.'
),
(
  'COU-2026-004', 'coutinho', 'act_583640952921224',
  '2026-07-28',
  'pausa_de_anuncio_vencedor',
  'pausar_vencedor',
  'alta',
  'não revertido',
  '{"campaign_id":"120237380899190111","adset_id":"120250826483050111","ad_id":"120250826483090111","nome":"AD07 - [FIVE] - Tenha um imóvel"}',
  'AD07 pausado (Ativo -> Inativo) em 28/07, junto com a troca de lote de criativos.',
  'Foi pausado um dos poucos criativos com CPL consistentemente abaixo da média e estável em duas janelas seguidas (R$ 31,43 e R$ 34,90). Não havia sinal de fadiga: CTR caiu só de 2,04% para 1,86% e o volume de leads se manteve idêntico (14 e 14). A pausa retirou uma fonte estável de lead barato justamente quando o lote novo ainda não tinha provado nada.',
  'Não pausar criativo cujo CPL esteja abaixo da média da campanha em duas janelas consecutivas. Checar CPL versus média da campanha na mesma janela antes de pausar. AD07 (120250826483090111) é candidato natural a reativação.',
  'CPL médio da campanha subiu de R$ 39,94 para R$ 59,07 (+47,9%) no período seguinte à pausa.'
),
(
  'COU-2026-005', 'coutinho', 'act_583640952921224',
  '2026-07-28',
  'subida_de_lote_grande_de_criativos_em_conjunto_unico',
  'subir_lote_grande_em_conjunto_maduro',
  'media',
  'não revertido',
  '{"campaign_id":"120237380899190111","adset_id":"120250826483050111","ads_criados":["120252308945960111","120252309101200111","120252309122010111","120252309154900111","120252309235490111","120252309258390111"]}',
  'Seis criativos novos publicados de uma vez, no mesmo minuto, no conjunto 120250826483050111 — repetição exata do padrão de 17/07 (COU-2026-001), apenas 11 dias depois.',
  'Repetição do padrão COU-2026-001. Quatro dos seis novos ficaram com menos de R$ 3 de gasto e zero lead. A aparente melhora de CPL foi puxada quase toda pelo AD09 recriado e pelo AD23 — os outros 4 criativos não performaram.',
  'Não repetir o padrão de subir lote grande. Máximo 2 criativos por vez. Ver regra de COU-2026-001.',
  null
),

-- ============================================================
-- DOLCEVIVERE
-- ============================================================
(
  'DV-2026-001', 'dolcevivere', 'act_1352822116344860',
  '2026-07-30',
  'pausa_de_anuncio_sem_leads_mantido_por_tempo_demais',
  null,
  'media',
  'pausado',
  '{"campaign_id":"52513926974931","nome_campanha":"[V4JO] [MOT3] [ONGOING] - [HOME CARE]","adset":"[00] [AUTO] [F] [INTERESSES: ALTA RENDA] [SP/RJ CAPITAL] [H/M 25-65]","ad_id":"52578046356331","nome_anuncio":"AD00 - [ARTE] [WHATS] - Quem cuida de quem você ama?"}',
  'Anúncio pausado após rodar sem gerar leads em 14 dias, apesar de CTR razoável (2,81%) e engajamento.',
  'O criativo gerou reações e 1 resposta de mensagem mas nenhum lead em 14 dias, mesmo no adset de melhor recorte. CTR razoável não converteu em ação de negócio — sinal de desalinhamento entre criativo e objetivo.',
  'Definir regra de corte automático: 0 leads após R$ 15-20 de gasto com impressões suficientes (>300) para indicar tendência. Não manter criativos de teste ativos além de ~7 dias sem nenhum lead.',
  null
),
(
  'DV-2026-002', 'dolcevivere', 'act_1352822116344860',
  '2026-08-06',
  'pausa_de_criativo_duplicado_com_cpl_alto',
  null,
  'media',
  'pausado',
  '{"campaign_id":"52513926974931","nome_campanha":"[V4JO] [MOT3] [ONGOING] - [HOME CARE]","ad_id":"52578057069931","nome_anuncio":"AD01 - Cópia - O cuidado que seu familiar merece"}',
  'Anúncio duplicado (cópia de teste) pausado após performance ruim.',
  'A cópia teve CTR quase metade do original (1,81% vs 3,33%) e CPL de R$ 45,40 — ~8x mais caro que o CPL médio da campanha irmã de formulário (R$ 7,92). Na última semana antes da pausa não gerou nenhum lead.',
  'Duplicar criativos para teste é válido, mas precisa de teto de gasto/tempo definido antes (ex.: pausar automaticamente se CPL > 3x o CPL médio após amostra mínima).',
  'R$ 21,63 gastos na última semana sem retorno.'
),
(
  'DV-2026-003', 'dolcevivere', 'act_1352822116344860',
  'Contínuo (últimos 30 dias)',
  'escolha_de_objetivo_de_campanha_inadequado',
  'objetivo_errado_para_o_kpi',
  'alta',
  'não corrigido',
  '{"campaign_id":"52513926974931","nome_campanha":"[V4JO] [MOT3] [ONGOING] - [HOME CARE]","objetivo":"OUTCOME_ENGAGEMENT"}',
  'Manter e testar múltiplos criativos (8+ variações) dentro de campanha com objetivo de Engajamento para tentar gerar leads via conversas de WhatsApp.',
  'Nenhuma otimização de criativo dentro do MOT3 resolveu o problema estrutural: o objetivo de campanha (Engajamento) não é otimizado pelo Meta para geração de lead. Os melhores criativos dessa campanha custam ordens de grandeza mais caro que a campanha de formulário nativo.',
  'Em vez de continuar testando criativos no MOT3, migrar o orçamento/verba de teste para estrutura de campanha com objetivo Leads (formulário nativo), replicando o padrão que já funciona no MOT2.',
  null
),
(
  'DV-2026-004', 'dolcevivere', 'act_1352822116344860',
  '2026-07-13 (criação)',
  'public_vencedor_reaproveitado_em_objetivo_diferente',
  'portar_targeting_entre_objetivos_diferentes',
  'media',
  null,
  '{"campaign_id":"52513926974931","nome_campanha":"[V4JO] [MOT3] [ONGOING] - [HOME CARE]","adset":"[00] [AUTO] [F] [INTERESSES: ALTA RENDA] [SP/RJ CAPITAL] [H/M 25-65]"}',
  'Reaproveitar o público "Alta Renda" (que funciona bem na campanha de formulário MOT2) dentro da campanha de engajamento MOT3.',
  'O público "Alta Renda" não é o fator limitante — ele provou funcionar em outro contexto. O gargalo é o objetivo/formato da campanha (Engajamento + WhatsApp), não a segmentação.',
  'Não assumir que público vencedor se replica automaticamente em campanhas com objetivo diferente. Validar objetivo de campanha antes de portar targeting entre estruturas.',
  null
),

-- ============================================================
-- LULIBABY
-- ============================================================
(
  'LUL-2026-001', 'lulibaby', 'act_547504311493941',
  '2026-08-04',
  'pausa_de_anuncio_e_campanha_vencedores',
  'pausar_vencedor',
  'alta',
  'não revertido — campanha segue PAUSADA em 13/08',
  '{"campaign_id":"120250773806540169","nome_campanha":"[V4JO] [MOT1] [ONGOING] - [CALÇADOS]","adset_id":"120250773806600169","nome_adset":"[00] [AUTO] [F] [MIX QUENTE] [CHUTEIRA]","ad_id":"120251722378170169","nome_anuncio":"AD08 - Chuteira Copa do mundo"}',
  'Em 04/08 às 00:40 o AD08 foi pausado (Ativo -> Inativo). Às 00:58 a campanha CALÇADOS inteira foi pausada. A verba foi realocada para a campanha ECOM-TESTE, cujo orçamento subiu de R$ 253,53 para R$ 340,00/dia no mesmo minuto.',
  'O AD08 tinha ROAS 6,30 — o melhor ROAS entre todos os anúncios com gasto acima de R$ 1.000 da conta, e 20% acima do ROAS da conta (5,24). A campanha CALÇADOS entregava com estabilidade: 21 dias seguidos a R$ 90-100/dia com CPM de R$ 33,60 (o mais barato entre as campanhas de volume). A leitura que provavelmente motivou a pausa foi o dia 03/08 isolado (R$ 101 gastos, 0 compras), mas é ruído — a campanha tinha 8 dias com ROAS acima de 4 nos 21 dias analisados.',
  'Reativar a campanha 120250773806540169 e o anúncio 120251722378170169 com orçamento reduzido (R$ 45-50/dia em vez dos R$ 87,81 originais), para reler a categoria em janela limpa de 7 dias antes de decidir em definitivo. A fonte de verba para a ECOM-TESTE deveria ter sido o adset LINHA CORPORAL (ROAS 2,95, CPA R$ 97 — o pior da conta).',
  'Ritmo de receita perdido: R$ 462/dia de receita a um custo de R$ 90/dia. Entre 04/08 e 13/08 (10 dias) equivale a ~R$ 4.600 de receita não gerada contra R$ 900 de verba economizada.'
),
(
  'LUL-2026-002', 'lulibaby', 'act_547504311493941',
  '2026-08-04',
  'migracao_de_conjunto_vencedor_para_cbo_dominado',
  'migrar_vencedor_para_cbo_dominado',
  'alta',
  'não revertido — clone segue ativo e sem entrega em 13/08',
  '{"adset_id_original":"120250773806600169","campaign_id_original":"120250773806540169","adset_id_clone":"120252207417220169","campaign_id_clone":"120250767210100169","nome":"[00] [AUTO] [F] [MIX QUENTE] [CHUTEIRA]"}',
  'Em 04/08 às 00:57 foi criado conjunto novo replicando o conjunto CHUTEIRA dentro da campanha ECOM-TESTE, com otimização por Valor e lance HIGHEST_VALUE. O conjunto original foi desativado junto com a campanha CALÇADOS um minuto depois.',
  'O conjunto clonado perdeu todo o histórico de aprendizado e entrou num CBO (ECOM-TESTE, R$ 340/dia) onde já existia o conjunto SKIN CARE com histórico consolidado. O algoritmo do CBO concentrou a verba no conjunto com histórico e o clone nunca recebeu volume suficiente: R$ 19,36 em 10 dias, contra R$ 75/dia que o original recebia. Além disso o conjunto foi mexido mais três vezes depois, reiniciando o pouco de aprendizado.',
  'Nunca migrar conjunto vencedor para dentro de um CBO que já tem conjunto dominante — o CBO não divide verba, ele concentra. Reativar o conjunto ORIGINAL (120250773806600169) na campanha original (120250773806540169) com orçamento próprio, e pausar o clone 120252207417220169.',
  'Perda integral da receita de calçados: ~R$ 4.000 em 10 dias. O clone não substituiu o original em nenhuma métrica.'
),
(
  'LUL-2026-003', 'lulibaby', 'act_547504311493941',
  '2026-08-07',
  'escala_agressiva_de_orcamento',
  'escalar_publico_quente_saturado',
  'alta',
  'corrigido parcialmente — gasto recuou a partir de 10/08',
  '{"campaign_id":"120250767210100169","nome_campanha":"[V4JO] [MOT1] [ONGOING] - [ECOM - TESTE]","adset_id":"120250772201350169","nome_adset":"[00] [AUTO] [F] [MIX QUENTE] [SKIN CARE]"}',
  'O orçamento CBO da ECOM-TESTE foi elevado de R$ 253,53 para R$ 340,00/dia em 04/08, e ao mesmo tempo a campanha CALÇADOS foi pausada, jogando toda a verba num único conjunto de público quente.',
  'ROAS caiu de 5,45 para 0,92 e CPA subiu de R$ 49,30 para R$ 172,39 — o conjunto passou a gastar 3x mais para trazer 4x menos compras. CPM praticamente não mudou (R$ 59,13 -> R$ 61,44), descartando leilão caro: o problema foi esgotamento de público qualificado. O conjunto é de público quente/mix com tamanho finito — dobrar a verba não dobra o público, só aumenta a frequência. Prova: assim que o gasto voltou para ~R$ 295/dia, o ROAS voltou a 5,50.',
  'Este conjunto tem teto de gasto eficiente em torno de R$ 250-300/dia. Não escalar acima disso. Escala nesta conta precisa vir de público NOVO (prospecção/lookalike) ou de reativar linhas subinvestidas (Sabonete Sólido ROAS 7,67; 10% de desconto ROAS 7,57).',
  'R$ 1.379,13 gastos em 3 dias para gerar R$ 1.273,06 — prejuízo direto de R$ 106. No ritmo anterior (ROAS 5,45), esses mesmos R$ 1.379 teriam gerado ~R$ 7.516. Perda estimada: R$ 6.240 de receita.'
),

-- ============================================================
-- PIEMON
-- ============================================================
(
  'PIE-2026-001', 'piemon', 'act_147401468324992',
  '2026-07-17 (última extensão) — expirou em 2026-07-27; formalizado como pausa em 2026-08-10',
  'conjunto_deixado_expirar_por_data_de_termino',
  'conjunto_expirado_por_esquecimento',
  'alta',
  'não revertido — conjunto segue PAUSED em 12/08',
  '{"campaign_id":"120236034893250694","adset_id":"120241712519610694","nome":"[00] [AUTO] [M] [ABERTO] [[CIDADES PRÓXIMAS + CACOAL]] [H / M / 18-65]"}',
  'Em 17/07 a data de término do conjunto foi estendida para 26/07. Depois disso ninguém mais estendeu. O conjunto expirou sozinho e ficou 14 dias sem entrega. Em 10/08 foi formalmente pausado.',
  'Este era o conjunto mais eficiente da conta no único objetivo mensurável: R$ 1,57 por conversa iniciada no WhatsApp, contra R$ 3,48 do CANAL VIP (2,2x mais caro) e R$ 355,33 do VISITAS AO PERFIL. Gerou 59 das 174 conversas do mês gastando 3,8% da verba. Foi desligado não por performance, mas por esquecimento operacional — a data de término venceu e ninguém renovou.',
  'Reativar o conjunto 120241712519610694 SEM data de término (vitalício). Nesta conta, data de término só faz sentido em conjunto amarrado a encarte com validade real — e mesmo esses precisam de checagem de calendário.',
  'No ritmo de 59 conversas em 15 dias (~3,9/dia a R$ 1,57), os 14 dias parados equivalem a ~55 conversas de WhatsApp não geradas. Substituir esse volume pelo CANAL VIP custaria ~R$ 191 — R$ 105 a mais para o mesmo resultado.'
),
(
  'PIE-2026-002', 'piemon', 'act_147401468324992',
  '2026-07-27 (padrão recorrente: repetido em 30/07 e 05/08)',
  'orcamento_alterado_multiplas_vezes_no_mesmo_dia',
  'multiplas_variaveis_no_mesmo_dia',
  'alta',
  'não revertido — padrão recorrente',
  '{"campaign_id":"120236034893250694","adset_id":"120246914010140694","nome":"[00] [AUTO] [M] [TABLOIDE] - [ABERTO] [CACOAL +65KM] [H / M / 18-65]"}',
  'Em 27/07: 4 mudanças de orçamento e 3 renomeações no mesmo conjunto em menos de 6 horas. Sequência: renomeado para FEHCA MES + extensão de data → criado conjunto novo FECHA MES → renomeado e R$ 15 -> R$ 25/dia → R$ 25 -> R$ 64/dia → renomeado de volta e orçamento R$ 64 -> R$ 15/dia → conjunto novo recebe R$ 64/dia → data encurtada. Repetido em 30/07 e 05/08.',
  'Múltiplas variáveis alteradas no mesmo dia no mesmo conjunto tornam impossível isolar o efeito de cada mudança. O custo real não é de mídia, é de aprendizado perdido — sem saber o que causou o que, o padrão se repete.',
  'Uma variável por vez. Mudanças de orçamento e de estrutura (renomear, criar conjunto) separadas por no mínimo 48h. Cada mudança registrada com data explícita de reavaliação.',
  null
)

-- ============================================================
-- WEFLORES (inserção condicional — só entra se o cliente existir no banco)
-- ============================================================
on conflict (id) do nothing;

insert into public.failed_optimizations
  (id, client_slug, account_id, data_acao, tipo_otimizacao, padrao, severidade, status_atual, entidade, acao_tomada, por_que_nao_deu_certo, recomendacao, custo_do_aprendizado)
select
  'WF-2026-001', 'weflores', 'act_1013880478985794',
  '2026-08-03',
  'placements_amplos_manuais',
  'placements_amplos_fora_do_instagram',
  'alta',
  'corrigido',
  '{"campaign_id":"120251518601580064","adset_ids":["120251518702190064","120251518702180064","120251518702170064","120251518601600064"],"nome_campanha":"[VENDAS] | WE Flores | AGO/2026","placements_incluidos":["Audience Network","Marketplace","Messenger","Pesquisa","coluna direita desktop","vídeo InStream","Facebook Reels","Threads"]}',
  'Campanha criada em 2026-08-03 com posicionamento manual amplo: além de Instagram, incluía Feed do Facebook em computadores, Audience Network, Marketplace, Messenger, Pesquisa (desktop e mobile), coluna direita, vídeo InStream, Facebook Reels e Threads.',
  'CTR extremamente baixo (0,37% a 0,57%) nos adsets de público frio, apesar de CPM baixo (R$ 5,43-R$ 8,54) — impressões baratas mas de qualidade ruim, gerando pouquíssimo engajamento. O adset de Interesses sozinho queimou R$ 698,24 com CTR de 0,39% antes da correção.',
  'NÃO reintroduzir Audience Network, Marketplace, Messenger, Pesquisa ou coluna direita nos placements desta conta. Manter apenas posicionamentos Instagram (ou testar Facebook Feed mobile isoladamente, nunca o pacote amplo de uma vez).',
  null
where exists (select 1 from public.clients where slug = 'weflores')
on conflict (id) do nothing;

# Lapzy — Tasks

## Doing

## Backlog

- [ ] TASK-022 · Feature — Heatmap de Velocidade no Traçado (bottom sheet detalhe de volta)
  Como piloto, quero visualizar um heatmap de velocidade sobreposto ao traçado da pista no detalhe de uma volta, para que eu identifique visualmente os pontos onde estou mais rápido e mais lento no circuito.
  refs: docs/lapzy_heatmap_velocidade.md, docs/lapzy_criacao_pista_setores.md, docs/tech.md, docs/telas.md

  ### Subtasks

  - [ ] 1. Coletar e armazenar amostras de velocidade GPS por volta (lat, lng, velocidade em m/s)
  - [ ] 2. Calcular velocidade interpolada para cada segmento do centerline da pista
  - [ ] 3. Normalizar velocidade por sessão (min/max) para mapeamento de cor
  - [ ] 4. Renderizar polilinha colorida no mapa (gradiente frio→quente: azul→verde→amarelo→vermelho)
  - [ ] 5. Implementar bottom sheet "detalhe de volta" acessível a partir da RaceSummaryScreen
  - [ ] 6. Testes unitários: cálculo de velocidade, normalização, mapeamento de cor
  - [ ] 7. Testes de widget: renderização do heatmap nos estados (dados completos, sem dados, volta única)

  ### Critérios de aceite

  - CA-HM-001-01: ao tocar em uma volta na RaceSummaryScreen, abre bottom sheet com mapa exibindo o traçado colorido pelo heatmap de velocidade
  - CA-HM-001-02: a escala de cor mapeia velocidade mínima da sessão para frio (azul) e máxima para quente (vermelho), com gradiente contínuo
  - CA-HM-001-03: quando não há dados de velocidade GPS suficientes para uma volta, o traçado é exibido em cor neutra sem heatmap
  - CA-HM-001-04: o bottom sheet é dispensável com swipe down e não bloqueia navegação
  - CA-HM-001-05: nenhuma amostra de velocidade é armazenada se a volta não tiver dados GPS com velocidade válida (≥ 0 m/s)

- [ ] TASK-021 · UX/UI — Melhorias na Tela de Corrida (pós-teste em pista)
  Como piloto, quero uma tela de corrida mais legível e informativa durante a sessão, para que eu consiga interpretar os dados sem tirar o foco da pilotagem.
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/identidade.md, docs/principios.md, docs/testing.md

  ### Contexto

  Após o primeiro teste real em kartódromo (2026-05-01, Rei dos Reis), identificou-se que a tela de corrida apresenta pontos de atrito de UX que dificultam a leitura rápida durante a pilotagem. Esta task consolida melhorias de apresentação e interação levantadas no teste.

  ### Melhorias a avaliar e implementar

  - **Legibilidade do cronômetro de volta**: verificar se o tamanho de fonte e contraste são adequados a ~60cm de distância com vibrações do kart
  - **Feedback de setor mais evidente**: quando um setor é concluído, o delta vs. melhor setor deve ser imediatamente legível (cor e tamanho)
  - **Número da volta atual**: exibir destaque maior para a volta corrente — facilita rastrear quantas voltas foram feitas sem interação
  - **Histórico inline de voltas**: considerar exibir as últimas 2-3 voltas com tempos para comparação imediata
  - **Estado "sem setor capturado"**: quando setores retornam null, a UI deve degradar com elegância (ex: "—" no lugar de campo vazio ou zero)

  ### Critérios de aceite

  - CA-UX-001-01: cronômetro de volta legível sem esforço a 60cm com tela em movimento
  - CA-UX-001-02: ao concluir um setor, o tempo e delta (verde/vermelho vs. melhor setor) ficam visíveis por pelo menos 3s sem ação do usuário
  - CA-UX-001-03: número da volta atual em destaque visual claro (hierarquia tipográfica diferente do cronômetro)
  - CA-UX-001-04: quando `sectorTime == null`, a UI exibe "—" (não zero, não vazio, não erro)
  - CA-UX-001-05: nenhuma nova interação exige mais de 2 toques

- [x] TASK-020 · Bug — Oscilação Sistemática de ~5s no Tempo de Volta
  Como piloto, quero que os tempos de volta reflitam o tempo real percorrido, sem oscilação sistemática entre voltas consecutivas, para que eu possa comparar voltas com precisão.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e análise dos dados de pista (2026-05-01)

  Durante o teste em pista foram gravadas duas sessões no kartódromo Rei dos Reis (Maceió/AL). Os dados revelam um padrão de oscilação **sistemático e regular** que não corresponde à variação real de pilotagem.

  ---

  #### Corrida 1 — "traçado rei dos reis" (17:03, 19 voltas)

  | Volta | lapMs | Cluster |
  |-------|-------|---------|
  | 1  | 74.958s | warm-up |
  | 2  | 69.964s | ~70s |
  | 3  | 70.021s | ~70s |
  | 4  | 65.039s | ~65s |
  | 5  | **259.929s** | anomalia (parada em pista) |
  | 6  | 70.005s | ~70s |
  | 7  | 65.071s | ~65s |
  | 8  | 69.923s | ~70s |
  | 9  | 65.041s | ~65s |
  | 10 | 64.980s | ~65s |
  | 11 | 70.066s | ~70s |
  | 12 | **64.917s** | ~65s ← melhor volta |
  | 13 | 70.041s | ~70s |
  | 14 | 65.034s | ~65s |
  | 15 | 64.944s | ~65s |
  | 16 | 65.033s | ~65s |
  | 17 | 69.972s | ~70s |
  | 18 | 64.997s | ~65s |
  | 19 | 69.987s | ~70s |

  **Cluster ~65s**: média 65.002s (8 voltas, desvio < 160ms)
  **Cluster ~70s**: média 69.990s (6 voltas, desvio < 150ms)
  **Delta entre clusters**: ~4.988s ≈ **5 segundos exatos**

  Setores (3 configurados): apenas S1 capturado em 4/19 voltas (21%); S2 e S3 = null em 100% das voltas.

  ---

  #### Corrida 2 — "Rei dos Reis 2" (17:48, 19 voltas)

  | Volta | lapMs | Setores (S1, S2, S3) | Obs |
  |-------|-------|----------------------|-----|
  | 1  | 74.945s | [45.000, null, null] | warm-up |
  | 2  | 75.007s | [null, null, null] | warm-up |
  | 3  | 65.079s | [null, null, null] | ~65s |
  | 4  | 69.964s | [null, null, null] | ~70s |
  | 5  | **95.008s** | [40.018, **0.001**, 9.987] | anomalia + S2 errado |
  | 6  | **110.000s** | [null, null, null] | anomalia |
  | 7  | 69.970s | [null, null, null] | ~70s |
  | 8  | 65.047s | [35.022, 5.055, 9.948] | ~65s |
  | 9  | 69.991s | [null, null, null] | ~70s |
  | 10 | **64.963s** | [34.960, 5.001, 10.034] | ~65s ← melhor volta |
  | 11 | 69.988s | [null, null, null] | ~70s |
  | 12 | 65.005s | [35.026, 5.008, 10.020] | ~65s |
  | 13 | 65.028s | [40.049, **0.002**, 9.994] | ~65s + S2 errado |
  | 14 | 69.984s | [34.987, 9.971, 10.069] | ~70s |
  | 15 | 65.008s | [40.028, 5.059, **4.899**] | ~65s + S3 baixo |
  | 16 | 69.982s | [39.982, 4.983, 10.023] | ~70s |
  | 17 | 70.033s | [null, null, null] | ~70s |
  | 18 | 65.001s | [null, null, null] | ~65s |
  | 19 | 69.942s | [null, null, null] | ~70s |

  **Cluster ~65s**: média 65.019s | **Cluster ~70s**: média 69.982s | **Delta**: **~4.963s**

  **Soma de setores ≠ lapMs** (voltas com dados completos):
  | Volta | S1+S2+S3 | lapMs | Gap |
  |-------|----------|-------|-----|
  | 8  | 50.025s | 65.047s | **15.022s** (23%) |
  | 10 | 49.995s | 64.963s | **14.968s** (23%) |
  | 12 | 50.054s | 65.005s | **14.951s** (23%) |
  | 14 | 55.027s | 69.984s | **14.957s** (21%) |
  | 16 | 54.988s | 69.982s | **14.994s** (21%) |

  Gap consistente de ~15s — indica que há um trecho do circuito não coberto por nenhum setor (provavelmente entre a linha S/C e o início do S1).

  ---

  #### O ideal vs. o que aconteceu

  | Métrica | Ideal | Obtido |
  |---------|-------|--------|
  | Variação entre voltas consecutivas (pilotagem estável) | ≤ 0.3s | **~5.0s** (sistemático) |
  | Setores cobertos por volta | 100% (toda volta tem S1+S2+S3) | **21% traçado 1 / ~42% traçado 2** |
  | S1+S2+S3 = lapMs | sim (diferença ≤ 0.1s) | **gap fixo de ~15s** |
  | S2 mínimo razoável | > 5s (qualquer setor de kart) | **0.001s e 0.002s** (claramente errado) |

  ---

  #### Hipóteses para a oscilação de ~5s

  A regularidade extrema (5.0s ± 0.1s entre os dois clusters, em DOIS traçados diferentes) aponta para uma causa sistemática no `LapDetector`, não em variação de pilotagem.

  **H1 — Detecção dupla por geometria**: A linha de largada/chegada de "traçado rei dos reis" tem `middlePoints: []` (segmento único) e `widthMeters: 3.0m`. A tolerância lateral de 1.5m pode estar causando dupla detecção em diferentes posições GPS ao longo do buffer, gerando um evento "cedo" (~65s) e um evento "tardio" (~70s) em voltas alternadas.

  **H2 — Clamping de `t` na interpolação**: Em `_crossingParams`, `t.clamp(0.0, 1.0)` força o timestamp ao início ou fim do segmento GPS quando a interseção cai fora do vetor de movimento. Isso pode introduzir erro sistemático quando a velocidade de cruzamento é baixa ou o ângulo é rasante, produzindo timestamps sempre "adiantados" ou "atrasados" de forma alternada.

  **H3 — Persistência do estado entre voltas**: `_previousPosition` e `_previousTimestamp` são preservados entre eventos de volta. Se o timestamp de um `LapCrossedEvent` é atribuído ao instante interpolado, mas `_previousTimestamp` não é atualizado para esse instante (continua sendo o timestamp do GPS), a próxima volta começa do timestamp GPS real — criando assimetria acumulada.

  **Hipótese mais provável (H3)**: O `LapDetector` usa o timestamp GPS do último ponto como âncora da próxima volta, mas registra o evento de volta no timestamp *interpolado*. Isso cria um drift: se a interpolação diz que o cruzamento foi 2.5s antes do GPS atualizar, a próxima volta começa 2.5s "mais tarde" no cálculo, resultando em volta seguinte ~5s mais longa. Na volta subsequente o drift se cancela, criando a oscilação alternada.

  ### Critérios de aceite

  - CA-BUG-003-01: em 20 voltas consecutivas de pilotagem estável, nenhum par de voltas adjacentes difere mais de 1.0s por causa do algoritmo de detecção (excluindo saídas de pit e falhas de GPS)
  - CA-BUG-003-02: a soma S1+S2+S3 é igual ao lapMs com diferença ≤ 100ms quando todos os setores são capturados
  - CA-BUG-003-03: S2 e S3 em "Rei dos Reis 2" nunca registram valores < 1s (indicam bug de timestamp, não tempo real)
  - CA-BUG-003-04: testes unitários reproduzem o cenário de oscilação com um stream GPS simulado e verificam que após o fix a alternância desaparece

- [ ] TASK-019 · Bug — Tela de Resumo com Dados Inconsistentes
  Como piloto, quero que a tela de resumo pós-corrida exiba dados corretos e coerentes, para que eu possa analisar minha performance sem questionar a veracidade dos números.
  refs: docs/telas.md, docs/lapzy_design_system.html, docs/principios.md, docs/testing.md

  ### Contexto

  Após o teste em pista (2026-05-01), a tela de resumo apresentou informações inconsistentes. Os dados gravados mostram possíveis fontes:

  - **Melhor volta incorreta**: com a oscilação de ~5s (TASK-020), a melhor volta calculada pode ser uma volta "curta" do cluster ~65s que não representa o tempo real de pista — ou pode ser inflada pelo cluster ~70s
  - **Setores do resumo**: quando setores são null em todas as voltas (caso do traçado 1), o resumo não deve exibir uma tabela de setores vazia ou com zeros — deve degradar com elegância
  - **Contagem de voltas**: verificar se voltas com lapMs anômalo (ex: 259s, 110s) entram no cálculo de média e melhor volta ou são filtradas
  - **Média de volta**: se calculada incluindo warm-up e anomalias, o número fica distorcido

  ### Critérios de aceite

  - CA-BUG-002-01: a "melhor volta" exibida no resumo corresponde ao menor `lapMs` entre voltas válidas (excluindo a primeira volta se for warm-up e voltas > 3× a mediana)
  - CA-BUG-002-02: quando todos os setores de todas as voltas são null, a seção de setores não é renderizada no resumo (nem como zeros, nem como "—")
  - CA-BUG-002-03: a média de volta exclui outliers (voltas > 2× a mediana do conjunto) do cálculo
  - CA-BUG-002-04: o número total de voltas exibido corresponde a todas as voltas registradas, incluindo warm-up e outliers (transparência ao piloto)
  - CA-BUG-002-05: testes de widget cobrem os estados: todos setores null, setores parciais, outliers presentes

- [x] TASK-018 · Bug — Setores Não Detectados na Maioria das Voltas
  Como piloto, quero que os tempos de cada setor sejam capturados de forma confiável em toda volta, para que eu possa identificar onde perco e ganho tempo no circuito.
  refs: docs/principios.md, docs/testing.md

  ### Contexto

  No teste em pista (2026-05-01), a taxa de captura de setores foi gravemente insuficiente:

  - **traçado rei dos reis** (3 setores): S1 capturado em apenas 4 de 19 voltas (21%); S2 e S3 capturados em **0 voltas**
  - **Rei dos Reis 2** (3 setores): setores capturados parcial ou totalmente em ~8 de 19 voltas (~42%); S2 com valores de 1ms e 2ms em 2 voltas (claramente erros de timestamp)

  ### Possíveis causas

  1. **`_crossSign == 0` ignora cruzamentos tangentes**: `if (signPrev == 0 || signCurr == 0) continue` descarta cruzamentos onde o ponto GPS cai exatamente sobre a reta da fronteira de setor — improvável em dados reais, mas pode mascarar cruzamentos com produtos vetoriais muito próximos de zero (precisão floating point)

  2. **GPS esparso + distanceFilter**: com `distanceFilter: 0`, o Geolocator emite posições a cada update de hardware (~1Hz no Samsung A35). Se a velocidade do kart é ~50km/h (~14m/s) e a zona de detecção da fronteira de setor tem largura de 6-7m, o kart atravessa a zona em ~0.4s — podendo saltar de um lado para o outro entre dois updates de 1Hz sem o vetor de movimento cruzar a linha no algoritmo

  3. **Múltiplos sub-segmentos em middlePoints**: as fronteiras de setor têm 15-40 middlePoints (curvas detalhadas). O algoritmo itera sobre todos os pares. Se o vetor de movimento GPS cruza a reta infinita de algum sub-segmento intermediário mas não dentro dos bounds do segmento, o cruzamento é descartado. Fronteiras de setor curvas podem ter sub-segmentos muito curtos onde a tolerância `bufferMeters/2` é insuficiente

  4. **Ordem de verificação**: S/F e setores são verificados no mesmo callback. Se o vetor GPS cruza tanto a S/F quanto uma fronteira de setor no mesmo update, apenas o evento de S/F é emitido (loop encerra com `continue` após emitir? não — mas o estado pode ficar inconsistente)

  ### Critérios de aceite

  - CA-BUG-001-01: em corrida com 3 setores configurados e piloto completando voltas inteiras, taxa de captura de setores ≥ 90% das voltas
  - CA-BUG-001-02: nenhum setor registra tempo < 1s (indica double-fire ou timestamp errado)
  - CA-BUG-001-03: quando um setor não é detectado (null), o próximo setor também é null — o app não tenta acumular tempo parcial sobre base inválida
  - CA-BUG-001-04: testes unitários reproduzem a falha de detecção com streams GPS simulados onde o kart atravessa a fronteira entre dois updates consecutivos

## Backlog

- [ ] TASK-017 · Modo Bolso — Foreground Service Android (US POCKET-003)
  Como piloto, quero que o GPS continue funcionando quando a tela apaga, para que eu possa guardar o celular no bolso sem perder a detecção de voltas.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e decisões de design

  **Fluxo natural do usuário**
  O piloto não precisa de toggle nem sensor: ele simplesmente bloqueia a tela com o botão de power e guarda o celular no bolso. O wakelock permanente (`WakelockPlus.enable()`) não impede esse gesto — o botão de power é um override do sistema. O Foreground Service garante que o GPS continue rodando com a tela bloqueada.

  **Problema**
  O Android pode matar o processo do app quando a tela apaga (especialmente em dispositivos com agressiva gestão de bateria, como Samsung). O `Geolocator.getPositionStream()` para de receber eventos sem um Foreground Service ativo.

  **Solução**
  Criar um Android Foreground Service que mantém o processo vivo e o GPS rodando durante toda a sessão de corrida. O serviço deve:
  - Iniciar quando a RaceScreen é montada
  - Exibir uma notificação persistente obrigatória (requisito Android para Foreground Service): "Lapzy · Corrida em andamento"
  - A notificação deve ter intent que traz o app ao foreground ao ser tocada
  - Parar quando a RaceScreen é desmontada (dispose)
  - Usar `foregroundServiceType: location` no AndroidManifest

  **Retorno ao app com corrida ativa**
  Quando o usuário abre o app (via notificação ou ícone) com a tela bloqueada e corrida em andamento:
  - O Flutter retorna ao foreground com estado preservado (processo vivo pelo Foreground Service)
  - A RaceScreen já está ativa em landscape (`setPreferredOrientations` continua valendo)
  - O `launchMode="singleTop"` no AndroidManifest impede criação de nova Activity

  **Stack**
  - Implementação nativa via MethodChannel em Kotlin (sem dependência de pacote externo)
  - Um único canal `lapzy/foreground_service` com métodos `start` e `stop`

  **Permissões adicionais**
  - `FOREGROUND_SERVICE` (obrigatória)
  - `FOREGROUND_SERVICE_LOCATION` (Android 14+, obrigatória)
  - Nenhuma permissão nova de localização — já solicitadas nas tasks anteriores

  ### Critérios de aceite

  - CA-POCKET-003-01: com tela bloqueada (botão de power), o LapDetector continua emitindo LapCrossedEvent e SectorCrossedEvent
  - CA-POCKET-003-02: uma notificação persistente "Lapzy · Corrida em andamento" fica visível na barra de status durante toda a corrida
  - CA-POCKET-003-03: tocar na notificação abre o app e exibe a RaceScreen em landscape com a corrida em andamento
  - CA-POCKET-003-04: ao encerrar a corrida (FINALIZAR), o Foreground Service é parado e a notificação desaparece
  - CA-POCKET-003-05: o Foreground Service não persiste após o app ser fechado pelo usuário (swipe no recents)
  - CA-POCKET-003-06: no Samsung A35 (Android 14), o GPS detecta voltas corretamente com a tela bloqueada por pelo menos 10 minutos contínuos

## Backlog

- [ ] TASK-015 · Modo Bolso — Proteção Contra Toque Acidental (US POCKET-001)
  Como piloto, quero que toques acidentais no bolso não interrompam a corrida, para que eu possa guardar o celular com segurança.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e decisões de design

  **Fluxo do usuário**
  O piloto bloqueia a tela manualmente (botão de power) e guarda o celular no bolso. O Foreground Service (TASK-017) mantém o GPS ativo. Quando tira o celular do bolso e abre o app — seja pela notificação ou pelo ícone — existe risco de toque acidental no botão FINALIZAR enquanto posiciona o celular na mão ou no suporte.

  **Gatilho revisado: retorno ao foreground**
  O overlay é acionado por `AppLifecycleState.resumed` com corrida ativa — ou seja, quando o usuário abre o app com a corrida em andamento. Não depende mais de wakelock por evento.

  **Solução**
  Quando o app passa de `paused → resumed` com corrida ativa, exibir overlay semitransparente com o texto "TOQUE PARA INTERAGIR" por 2 segundos bloqueando todos os toques.

  **Distinguir retorno ao foreground de uso normal**
  - Usar `WidgetsBindingObserver.didChangeAppLifecycleState`
  - Ao detectar `AppLifecycleState.resumed` com `_hasStarted == true`, setar `_lockedOnResume = true` e exibir overlay
  - Ao detectar o primeiro `PointerDownEvent` durante o bloqueio, remover overlay imediatamente
  - Se o app nunca saiu do foreground (usuário está olhando para a tela), o evento `resumed` não dispara — sem overlay

  **Dependência**
  TASK-017 (Foreground Service) deve estar concluída antes.

  ### Critérios de aceite

  - CA-POCKET-001-01: ao abrir o app (notificação ou ícone) com corrida ativa, um overlay "TOQUE PARA INTERAGIR" é exibido por 2 segundos bloqueando todos os toques
  - CA-POCKET-001-02: após o overlay desaparecer (2s ou toque do usuário), a tela responde normalmente
  - CA-POCKET-001-03: quando o usuário já está com o app em foreground (sem ter bloqueado a tela), o overlay NÃO aparece
  - CA-POCKET-001-04: o botão FINALIZAR não pode ser ativado durante o período de bloqueio do overlay

- [ ] TASK-014 · Gerenciamento de Traçados (US TRACK-001)
  Como piloto, quero visualizar, editar e excluir os traçados que configurei, para que eu mantenha minha biblioteca de pistas organizada sem perder o histórico de corridas associado a elas.
  refs: docs/lapzy_tela_inicial.md, docs/lapzy_tela_criacao_pista.md, docs/lapzy_criacao_pista_setores.md, docs/lapzy_tela_listagem_corridas.md, docs/lapzy_design_system.html, docs/principios.md, docs/identidade.md, docs/testing.md

  ### Contexto e decisões de design

  **Acesso pela Home**
  - Novo ícone na top bar da HomeScreen, seguindo o mesmo padrão do ícone de histórico (relógio)
  - Posicionamento: avaliar na implementação se o ícone de pistas entra ao lado do histórico (esquerda) ou em outra posição que não polua o layout minimalista existente
  - Ícone sugerido: mapa/circuito (ex: `Icons.map_outlined` ou SVG equivalente ao estilo dos demais ícones da top bar)

  **TrackListScreen**
  - Layout idêntico à RaceListScreen: top bar com `‹` + label "TRAÇADOS" centralizado
  - Cada item: nome do traçado (bold) + data de criação formatada (pt-BR, ex: "29 abr 2026 · 14:32") + seta `›`
  - Ordenação: mais recente no topo (createdAt decrescente)
  - Estado vazio: mensagem "Nenhum traçado configurado." + subtítulo "Crie um traçado para começar a cronometrar." + botão ghost verde "CRIAR TRAÇADO"
  - Swipe para esquerda em qualquer item → exibe ação de exclusão (ver fluxo de exclusão abaixo)

  **TrackDetailScreen (visualização)**
  - Reutiliza o layout da tela de criação (mapa + painel inferior) em modo somente leitura
  - Mapa exibe o traçado completo: polyline do centerline, linha de largada/chegada, setores coloridos
  - Gestos de câmera habilitados (zoom/scroll); gestos de edição desabilitados
  - Painel inferior mostra: nome da pista, data de criação, número de setores configurados
  - Botão "EDITAR" (ghost verde) → abre fluxo de edição
  - Botão `‹` (back) → volta para TrackListScreen

  **Fluxo de edição**
  - Ao tocar em "EDITAR", abre a tela de criação de pista (TrackCreationScreen) pré-populada com os dados exatos do traçado selecionado: centerline, posição S/C, setores, nome
  - O wizard inicia no passo 0 (TRAÇADO) mas com todos os dados já preenchidos — usuário pode avançar passo a passo ou tocar em nós já concluídos para editar diretamente
  - Ao salvar, o registro existente é atualizado (mesmo `id`, `updatedAt` atualizado) — histórico de corridas associado permanece intacto
  - TrackCreationScreen precisa aceitar um `Track? initialTrack` opcional para distinguir criação de edição

  **Fluxo de exclusão**
  - Swipe para a esquerda no item da lista revela painel vermelho com ícone de lixeira e label "EXCLUIR"
  - Ao confirmar o swipe (soltar após > 50% da largura) OU tocar no painel revelado → exibe bottom sheet de confirmação:
    - Título: "Excluir traçado?"
    - Corpo: "Nenhum histórico será perdido, mas você não poderá mais iniciar novas corridas com essas configurações."
    - Botão primário: "EXCLUIR" (vermelho `Color(0xFFFF3B30)`)
    - Botão secundário: "CANCELAR" (ghost, branco baixa opacidade)
  - Ao confirmar: remove do TrackRepository + remove da lista com animação de saída
  - RaceSessionRecord mantém `trackName` desnormalizado (já implementado em TASK-012) — histórico não é afetado

  ### Critérios de aceite

  - CA-TRACK-001-01: ícone de traçados na HomeScreen navega para TrackListScreen
  - CA-TRACK-001-02: TrackListScreen exibe todos os traçados salvos, ordenados por createdAt decrescente, com nome e data de criação formatada
  - CA-TRACK-001-03: TrackListScreen em estado vazio exibe mensagem adequada e botão "CRIAR TRAÇADO"
  - CA-TRACK-001-04: toque em um item da lista navega para TrackDetailScreen com o traçado correto carregado no mapa (centerline, S/C, setores)
  - CA-TRACK-001-05: TrackDetailScreen exibe nome, data de criação e número de setores no painel inferior; mapa é interativo (zoom/scroll) mas sem gestos de edição
  - CA-TRACK-001-06: botão "EDITAR" em TrackDetailScreen abre TrackCreationScreen com todos os campos pré-populados com os dados do traçado selecionado
  - CA-TRACK-001-07: salvar a edição atualiza o registro existente (mesmo id) sem afetar RaceSessionRecords que referenciam esse traçado
  - CA-TRACK-001-08: swipe para esquerda em item da lista revela ação de exclusão; ao confirmar, exibe bottom sheet com texto exato definido acima
  - CA-TRACK-001-09: ao confirmar exclusão, traçado é removido do TrackRepository e da lista com animação; histórico de corridas não é alterado
  - CA-TRACK-001-10: ao cancelar a exclusão, o item retorna à posição original sem nenhuma alteração

## Done (recente)

- [x] TASK-013 · Histórico de Corridas (US HIST-001)
  Como piloto, quero acessar o histórico de todas as minhas corridas anteriores e revisar o resumo de cada uma, para que eu possa acompanhar minha evolução ao longo do tempo.
  refs: docs/lapzy_tela_listagem_corridas.md, docs/telas.md, docs/lapzy_design_system.html, docs/principios.md, docs/identidade.md

- [x] TASK-012 · Persistência Local de Sessões de Corrida (US PERSIST-002)
  Como piloto, quero que os dados de cada corrida sejam salvos automaticamente no dispositivo, para que eu possa consultar meu histórico mesmo sem conexão com a internet.
  refs: docs/telas.md, docs/principios.md
  notas de arquitetura:
  - Usar shared_preferences + JSON como storage local
  - Modelo RaceSessionRecord deve ser independente de RaceSessionSnapshot (snapshot é live, record é histórico imutável)
  - IDs devem ser UUIDs v4 — nunca timestamp — para não colidir em sync multi-dispositivo
  - Datas em ISO 8601 (string) para portabilidade de sync
  - Serialização de enums via string (ex: "melhorVolta"), nunca por índice — índice quebra com reordenação futura
  - createdAt obrigatório em todo record — será usado para resolução de conflitos no sync
  - LapResult precisa de toJson/fromJson (lapMs: int, sectors: List<int?>)
    critérios de aceite:
  - CA-PERSIST-002-01: RaceSessionRecord contém: id (UUID v4), trackId, trackName (desnormalizado), date (ISO 8601), laps (lapMs + sectors por volta), bestLapMs, createdAt
  - CA-PERSIST-002-02: sessão é salva automaticamente no encerramento da corrida, antes de navegar para RaceSummaryScreen (sem ação do usuário)
  - CA-PERSIST-002-03: histórico de sessões persiste após reiniciar o app
  - CA-PERSIST-002-04: RaceSessionRepository expõe save(record), loadAll(), delete(id) — mesmo padrão do TrackRepository
  - CA-PERSIST-002-05: RaceSummaryScreen pode ser construída a partir de um RaceSessionRecord (entrada alternativa via histórico)

- [x] TASK-011 · Persistência Local de Pistas (US PERSIST-001)
  Como piloto, quero que as pistas que criei sejam salvas no dispositivo, para que eu não precise reconfigurá-las a cada sessão.
  refs: docs/lapzy_criacao_pista_setores.md, docs/tech.md, docs/principios.md
  notas de arquitetura:
  - Usar shared_preferences + JSON como storage local
  - IDs devem ser UUIDs v4 — Track.id hoje usa timestamp (DateTime.now().millisecondsSinceEpoch.toString()); migrar para uuid package
  - GeoPoint serializa como {lat, lng}; TrackLine serializa como {a, b, middlePoints, widthMeters}
  - TrackRepository deve carregar pistas do storage na inicialização do app (antes de renderizar HomeScreen)
  - lastSession deve ser atualizado ao salvar uma RaceSessionRecord para esta pista
  - createdAt e updatedAt obrigatórios em Track para futura reconciliação de sync
    critérios de aceite:
  - CA-PERSIST-001-01: pista criada (nome, linha de largada/chegada, setores) persiste após reiniciar o app
  - CA-PERSIST-001-02: todos os campos geográficos são restaurados com precisão (lat/lng, widthMeters, middlePoints de linhas curvas)
  - CA-PERSIST-001-03: Track.id é UUID v4 gerado no momento da criação
  - CA-PERSIST-001-04: TrackRepository inicializa carregando dados do storage (loadAll assíncrono, chamado em main antes do runApp ou via FutureBuilder na HomeScreen)
  - CA-PERSIST-001-05: pista deletada é removida do storage imediatamente

- [x] TASK-005 · Resumo Pós-Corrida
  refs: docs/telas.md, docs/lapzy_design_system.html, docs/principios.md

- [x] TASK-010 · Encerramento de Corrida Anti-Acidental (US END-001)
  Como piloto, quero um mecanismo de encerramento que evite toques acidentais mas que seja rápido quando intencional, para que eu não encerre a corrida por engano enquanto dirijo.
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/principios.md, docs/telas.md
  critérios de aceite:
  - CA-END-001-01: swipe a partir da borda direita (> 30px para dentro) → botão FINALIZAR fica visível em destaque (Color(0xFFFF3B30))
  - CA-END-001-02: botão visível sem toque por 3s → retorna ao estado pequeno/opaco original
  - CA-END-001-03: toque no botão FINALIZAR → sessão encerrada imediatamente, app navega para ResumoScreen e dados salvos automaticamente (sem ação do usuário)
  - CA-END-001-04: ao carregar ResumoScreen, dados da sessão (voltas, tempos, setores) estão disponíveis e corretos; NÃO há botão "Descartar" ou opção de cancelar salvamento


- [x] TASK-008 · Tempos Parciais por Setor em Tempo Real (US RACE-003)
  Como piloto, quero ver o tempo parcial de cada setor enquanto ainda estou na volta, para que eu identifique onde perdi ou ganhei tempo sem esperar o fim da volta.
  refs: docs/tela_corrida_svg.md, docs/lapzy_criacao_pista_setores.md, docs/lapzy_design_system.html, docs/principios.md, docs/identidade.md
  critérios de aceite:
  - CA-RACE-003-01: ao cruzar o início do S1, badge S1 fica ativo (Color(0xFF00B0FF)) e cronômetro de split S1 inicia
  - CA-RACE-003-02: ao cruzar fim S1/início S2, tempo final do S1 é exibido no badge S1 e badge S2 fica ativo (Color(0xFFFFD600))
  - CA-RACE-003-03: ao cruzar a linha de chegada, todos os badges exibem os tempos finais dos setores da volta
  - CA-RACE-003-04: se a pista NÃO possui setores definidos, badges de setor NÃO são exibidos e o layout central mantém apenas o tempo de volta

- [x] TASK-009 · Feedback Visual de Borda por Estado de Volta (US RACE-004)
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/identidade.md, docs/principios.md

- [x] TASK-007 · Cronômetro de Volta em Tempo Real (US RACE-002)
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/principios.md, docs/telas.md

- [x] TASK-003 · Tela de Corrida
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/principios.md, docs/telas.md

- [x] TASK-006 · Configurar Google Maps API Key para produção
  Substituir o placeholder `YOUR_MAPS_API_KEY` no AndroidManifest.xml pela chave real.
  Criar chave restrita (SHA-1 do keystore de release + package com.lapzy.lapzy) no Google Cloud Console.
  Verificar se Maps SDK for Android está ativado no projeto.

- [x] TASK-004 · Criação de Pista
  refs: docs/lapzy_criacao_pista_setores.md, docs/tech.md, docs/telas.md

- [x] TASK-002 · Bottom Sheet Seleção de Pista
  refs: docs/bottom_sheet_pista.md, docs/lapzy_design_system.html, docs/principios.md, docs/fluxo.md

- [x] TASK-001 · Tela Inicial
  refs: docs/lapzy_tela_inicial.md, docs/lapzy_design_system.html, docs/principios.md

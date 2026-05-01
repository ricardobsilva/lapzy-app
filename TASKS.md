# Lapzy — Tasks

## Doing

## Backlog

- [ ] TASK-017 · Modo Bolso — Foreground Service Android (US POCKET-003)
  Como piloto, quero que o GPS continue funcionando quando a tela apaga, para que eu possa guardar o celular no bolso sem perder a detecção de voltas.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e decisões de design

  **Problema**
  O Android pode matar o processo do app quando a tela apaga (especialmente em dispositivos com agressiva gestão de bateria, como Samsung). O `Geolocator.getPositionStream()` para de receber eventos sem um Foreground Service ativo.

  **Solução**
  Criar um Android Foreground Service que mantém o processo vivo e o GPS rodando durante toda a sessão de corrida. O serviço deve:
  - Iniciar quando a RaceScreen é montada
  - Exibir uma notificação persistente obrigatória (requisito Android para Foreground Service): "Lapzy · Corrida em andamento"
  - Parar quando a RaceScreen é desmontada (dispose)
  - Usar `foregroundServiceType: location` no AndroidManifest

  **Stack**
  - Pacote recomendado: `flutter_foreground_task` (mantido, suporta location type)
  - Alternativa nativa: implementar diretamente via MethodChannel em Kotlin

  **Permissões adicionais**
  - `FOREGROUND_SERVICE` (obrigatória)
  - `FOREGROUND_SERVICE_LOCATION` (Android 14+, obrigatória)
  - Nenhuma permissão nova de localização — já solicitadas nas tasks anteriores

  ### Critérios de aceite

  - CA-POCKET-003-01: com tela apagada (botão de desligar tela), o LapDetector continua emitindo LapCrossedEvent e SectorCrossedEvent
  - CA-POCKET-003-02: uma notificação persistente "Lapzy · Corrida em andamento" fica visível na barra de status durante toda a corrida
  - CA-POCKET-003-03: ao encerrar a corrida (FINALIZAR), o Foreground Service é parado e a notificação desaparece
  - CA-POCKET-003-04: o Foreground Service não persiste após o app ser fechado pelo usuário (swipe no recents)
  - CA-POCKET-003-05: no Samsung A35 (Android 14), o GPS detecta voltas corretamente com a tela apagada por pelo menos 10 minutos contínuos

- [ ] TASK-016 · Modo Bolso — Wakelock Adaptativo (US POCKET-002)
  Como piloto, quero que a tela apague durante a corrida quando não há eventos, para que a bateria dure a sessão inteira sem precisar de suporte de celular.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e decisões de design

  **Problema**
  Hoje `WakelockPlus.enable()` mantém a tela acesa durante toda a corrida. Com o celular no bolso, isso drena a bateria rapidamente e gera risco de toque acidental.

  **Solução: wakelock baseado em eventos**
  - Remover o `WakelockPlus.enable()` permanente do `initState`
  - Ao detectar um evento de corrida (LapCrossedEvent ou SectorCrossedEvent), chamar `WakelockPlus.enable()` por 5 segundos e depois `WakelockPlus.disable()`
  - O Android gerencia o apagamento da tela naturalmente pelo timeout do sistema

  **Comportamento esperado**
  - Tela liga brevemente a cada cruzamento de linha (volta ou setor) para mostrar o feedback visual
  - Entre eventos, a tela apaga normalmente pelo timeout do usuário
  - Ao tocar na tela, ela acende normalmente (comportamento padrão Android)

  **Dependência**
  TASK-017 (Foreground Service) deve estar concluída antes — sem ela, apagar a tela pode matar o GPS.

  ### Critérios de aceite

  - CA-POCKET-002-01: a tela apaga automaticamente após o timeout de display configurado pelo usuário, sem nenhum toque
  - CA-POCKET-002-02: ao cruzar a linha de largada/chegada, a tela acende por exatamente 5 segundos e apaga em seguida
  - CA-POCKET-002-03: ao cruzar uma fronteira de setor, a tela acende por exatamente 5 segundos e apaga em seguida
  - CA-POCKET-002-04: tocar na tela durante a corrida acende a tela normalmente (wakelock não interfere com interação do usuário)
  - CA-POCKET-002-05: ao encerrar a corrida, `WakelockPlus.disable()` é chamado (comportamento idêntico ao atual no dispose)

- [ ] TASK-015 · Modo Bolso — Proteção Contra Toque Acidental (US POCKET-001)
  Como piloto, quero que toques acidentais no bolso não interrompam a corrida, para que eu possa guardar o celular com segurança.
  refs: docs/principios.md, docs/testing.md

  ### Contexto e decisões de design

  **Problema**
  Com a tela acesa no bolso (estado atual) ou acendendo por eventos (após TASK-016), existe risco de toque acidental no botão FINALIZAR. Embora o botão exija 2s de pressão contínua, tecido de bolso pode simular isso.

  **Solução: lock de toque quando tela acende por evento**
  Quando a tela acende via wakelock de evento (não por toque do usuário), bloquear input por 2 segundos exibindo um overlay semitransparente com o texto "TOQUE PARA INTERAGIR".

  **Distinguir "acendeu por evento" de "acendeu por toque"**
  - Ao disparar o wakelock de evento, setar um flag `_screenOnByEvent = true`
  - Ao detectar o primeiro `PointerDownEvent` na tela, limpar o flag e remover o overlay
  - Se a tela já estava acesa (usuário estava olhando), o flag não é setado — sem overlay

  **Dependência**
  TASK-016 (Wakelock Adaptativo) deve estar concluída antes.

  ### Critérios de aceite

  - CA-POCKET-001-01: quando a tela acende por evento de corrida (cruzamento de linha), um overlay "TOQUE PARA INTERAGIR" é exibido por 2 segundos bloqueando todos os toques
  - CA-POCKET-001-02: após o overlay desaparecer (2s ou toque do usuário), a tela responde normalmente
  - CA-POCKET-001-03: quando o usuário toca a tela manualmente para acendê-la (sem evento de corrida), o overlay NÃO aparece
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

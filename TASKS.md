# Lapzy — Tasks

## Doing

## Backlog

- [ ] TASK-010 · Encerramento de Corrida Anti-Acidental (US END-001)
  Como piloto, quero um mecanismo de encerramento que evite toques acidentais mas que seja rápido quando intencional, para que eu não encerre a corrida por engano enquanto dirijo.
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/principios.md, docs/telas.md
  critérios de aceite:
  - CA-END-001-01: swipe a partir da borda direita (> 30px para dentro) → botão FINALIZAR fica visível em destaque (Color(0xFFFF3B30))
  - CA-END-001-02: botão visível sem toque por 3s → retorna ao estado pequeno/opaco original
  - CA-END-001-03: toque no botão FINALIZAR → sessão encerrada imediatamente, app navega para ResumoScreen e dados salvos automaticamente (sem ação do usuário)
  - CA-END-001-04: ao carregar ResumoScreen, dados da sessão (voltas, tempos, setores) estão disponíveis e corretos; NÃO há botão "Descartar" ou opção de cancelar salvamento

- [ ] TASK-009 · Feedback Visual de Borda por Estado de Volta (US RACE-004)
  Como piloto, quero que a borda da tela mude de cor quando algo relevante acontece (PR, melhor volta, volta pior), para que eu receba feedback imediato sem precisar ler nenhum texto.
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/identidade.md, docs/principios.md
  critérios de aceite:
  - CA-RACE-004-01: volta mais lenta que a melhor (delta > 0) → borda Color(0xFFFF3B30) com stroke-width >= 8
  - CA-RACE-004-02: melhor volta da sessão (não é PR histórico) → borda Color(0xFFBF5AF2) e DeltaDisplay exibe "MELHOR" em Color(0xFFBF5AF2)
  - CA-RACE-004-03: Personal Record (melhor volta histórica da pista) → borda Color(0xFF00E676) com animação de pulso, badge "PERSONAL RECORD" no topo central e DeltaDisplay exibe delta positivo em Color(0xFF00E676)
  - CA-RACE-004-04: 3 segundos após mudança de estado sem novo evento → borda retorna ao estado neutro

- [ ] TASK-008 · Tempos Parciais por Setor em Tempo Real (US RACE-003)
  Como piloto, quero ver o tempo parcial de cada setor enquanto ainda estou na volta, para que eu identifique onde perdi ou ganhei tempo sem esperar o fim da volta.
  refs: docs/tela_corrida_svg.md, docs/lapzy_criacao_pista_setores.md, docs/lapzy_design_system.html, docs/principios.md, docs/identidade.md
  critérios de aceite:
  - CA-RACE-003-01: ao cruzar o início do S1, badge S1 fica ativo (Color(0xFF00B0FF)) e cronômetro de split S1 inicia
  - CA-RACE-003-02: ao cruzar fim S1/início S2, tempo final do S1 é exibido no badge S1 e badge S2 fica ativo (Color(0xFFFFD600))
  - CA-RACE-003-03: ao cruzar a linha de chegada, todos os badges exibem os tempos finais dos setores da volta
  - CA-RACE-003-04: se a pista NÃO possui setores definidos, badges de setor NÃO são exibidos e o layout central mantém apenas o tempo de volta

- [ ] TASK-007 · Cronômetro de Volta em Tempo Real (US RACE-002)
  Como piloto em pista, quero ver o tempo da volta atual sendo atualizado em tempo real e o delta em relação à melhor volta, para que eu saiba se estou mais rápido ou mais lento sem desviar o olhar por mais de 1 segundo.
  refs: docs/tela_corrida_svg.md, docs/lapzy_design_system.html, docs/principios.md, docs/telas.md
  critérios de aceite:
  - CA-RACE-002-01: ao cruzar a linha de largada pela 1ª vez, cronômetro inicia do zero e LapTimeDisplay atualiza a >= 10Hz
  - CA-RACE-002-02: ao cruzar a linha novamente (>= 2ª volta), registra tempo anterior, calcula delta (tempo_atual − melhor_volta_sessão); DeltaDisplay "▲ +X.XXX" em Color(0xFF00E676) se delta > 0; "▼ −X.XXX" em Color(0xFFFF3B30) se delta < 0
  - CA-RACE-002-03: na 1ª volta, não exibe delta; LapNumberDisplay exibe "1"

- [ ] TASK-005 · Resumo Pós-Corrida
  refs: docs/telas.md, docs/lapzy_design_system.html, docs/principios.md

## Done

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
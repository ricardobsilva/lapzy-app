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

- [ ] TASK-008 · Tempos Parciais por Setor em Tempo Real (US RACE-003)
  Como piloto, quero ver o tempo parcial de cada setor enquanto ainda estou na volta, para que eu identifique onde perdi ou ganhei tempo sem esperar o fim da volta.
  refs: docs/tela_corrida_svg.md, docs/lapzy_criacao_pista_setores.md, docs/lapzy_design_system.html, docs/principios.md, docs/identidade.md
  critérios de aceite:
  - CA-RACE-003-01: ao cruzar o início do S1, badge S1 fica ativo (Color(0xFF00B0FF)) e cronômetro de split S1 inicia
  - CA-RACE-003-02: ao cruzar fim S1/início S2, tempo final do S1 é exibido no badge S1 e badge S2 fica ativo (Color(0xFFFFD600))
  - CA-RACE-003-03: ao cruzar a linha de chegada, todos os badges exibem os tempos finais dos setores da volta
  - CA-RACE-003-04: se a pista NÃO possui setores definidos, badges de setor NÃO são exibidos e o layout central mantém apenas o tempo de volta

- [ ] TASK-005 · Resumo Pós-Corrida
  refs: docs/telas.md, docs/lapzy_design_system.html, docs/principios.md

## Done

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
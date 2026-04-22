# Lapzy — Tela de Criação de Pista

> **Fonte de verdade visual:** `knowledge_base/Tela de Corrida — SVG/lapzy_track_creation.html`
> **Referência cruzada:** `lapzy_criacao_pista_setores.md` (geometria de snap, setores, linha de largada)

---

## Fluxo geral

Wizard linear de 5 passos. O avanço é sequencial; retroceder é permitido via toque em nó já concluído.

| Passo | Nó | Label | Descrição |
|---|---|---|---|
| 0 | TR | TRAÇADO | Usuário traça o circuito tocando no mapa |
| 1 | S/C | LARGADA | Usuário arrasta para marcar a linha de largada |
| 2 | S1 | SETORES | Usuário define até 3 setores (opcional) |
| 3 | ① | NOME | Usuário digita o nome da pista |
| 4 | ✓ | SALVAR | Confirmação e acesso à corrida |

> **Nota:** o passo 0 (TRAÇADO) não existe no protótipo original — foi adicionado porque toda a lógica de snap de S/C e setores (`lapzy_criacao_pista_setores.md`) requer um centerline GPS definido. Os demais passos seguem exatamente o protótipo.

---

## Layout

Coluna vertical (não Stack full-screen):

```
SafeArea
└── Column
    ├── _ProgBar              ← barra de progresso fixa (height ~54px)
    ├── Expanded
    │   └── Stack
    │       ├── GoogleMap     ← ocupa todo o Expanded
    │       ├── Overlay hint  ← badge pill no topo do mapa
    │       ├── Overlay back  ← botão ← canto superior esquerdo
    │       └── Overlay draw  ← CustomPaint durante gestos S/C
    └── _BottomPanel          ← painel fixo inferior, conteúdo troca por passo
```

---

## Barra de progresso (_ProgBar)

- 5 nós conectados por 4 linhas
- **Nó ativo:** círculo verde (`#00E676`), texto preto
- **Nó concluído:** círculo verde translúcido, ícone ✓ verde, clicável (volta ao passo)
- **Nó futuro:** círculo escuro (`#1C1C1C`), texto cinza (`#FFFFFF1F`), não clicável
- **Linha concluída:** `#00E676` com alpha 40%; linha futura: `#FFFFFF14`
- Label abaixo de cada nó: 8px, monospace, maiúsculo

---

## Mapa

- Google Maps em modo normal por padrão
- `myLocationEnabled: true` — indicador GPS nativo do Maps
- `zoomControlsEnabled: false` — sem controles nativos
- Gestos de câmera (scroll/zoom) habilitados **apenas no passo 0 (TRAÇADO)**
- Hint text flutuante no centro-topo (badge pill preto translúcido, borda branca 12%)

---

## Painel inferior (_BottomPanel)

Fundo sólido `#141414`, borda superior `#FFFFFF14`, padding 14px lateral.

### Painel 0 — TRAÇADO

- **Título:** "Traçado da pista" (Rajdhani 12px bold uppercase, branco 50%)
- **Desc:** "Toque no mapa para marcar os pontos do circuito." (12px, branco 28%)
- **Ação:** botão FECHAR PISTA (verde, largura total, `key: close_track_button`) — aparece somente quando há ≥ 3 pontos

**Hints no mapa:**
- < 3 pontos: "Toque no mapa para traçar a pista"
- ≥ 3 pontos: "Toque em FECHAR PISTA para finalizar"

### Painel 1 — S/C (LARGADA)

- **Título:** "Linha de largada / chegada"
- **Desc:** "Arraste um traço no mapa. Arraste o marcador para reposicionar."
- **Gestos de câmera:** desabilitados neste passo
- **Ação:** botão [Confirmar →] (verde) — desabilitado até que S/C seja definida

**Interação:**
1. Usuário arrasta um traço livre sobre o mapa
2. Durante o arraste: linha desenhada em CustomPaint (verde `#00E676`, stroke 4px, rounded caps)
3. Ao soltar: midpoint do traço é snapado ao centerline via `TrackGeometry.snapToDist` em coordenadas de tela
4. Linha perpendicular calculada e exibida como Polyline branca (width 4) no mapa
5. Marcador S/C posicionado no ponto do centerline
6. Botão "Confirmar →" fica habilitado

**Hint no mapa:**
- S/C não definida: "Arraste para marcar a largada"
- S/C definida: "Arraste o marcador para reposicionar"

### Painel 2 — SETORES

- **Título:** "Setores" + "(opcional)" em cinza (Rajdhani + SpaceMono 10px)
- **Desc:** "Arraste ao longo da pista para definir cada setor."
- **Lista de setores:** itens com dot colorido + label ("Setor 1/2/3") + botão ✕ para remover
- **Estado vazio:** "Nenhum setor ainda." (12px, branco 28%)
- **Ação:** [Continuar →] (sempre habilitado — setores são opcionais)

**Interação:**
- Primeiro arraste → cria S1 (azul `#00B0FF`)
- Segundo arraste → cria S2 (amarelo `#FFD600`)
- Terceiro arraste → cria S3 (laranja `#FF6D00`)
- Após 3 setores: arraste ignorado
- Remover um setor (✕) permite redesenhá-lo

**Hint no mapa:**
- Setores restantes: "Arraste ao longo da pista · duplo clique navega"
- Todos definidos: "Todos os setores definidos"

### Painel 3 — NOME

- **Título:** "Nome da pista"
- **Input:** campo de texto (`key: track_name_field`), placeholder "Nome da pista"
  - Fundo `#1C1C1C`, borda `#FFFFFF14`, border-radius 8px
  - Focus: borda verde `#00E67666`
- **Ações:**
  - [← Voltar] (ghost button) → volta ao passo 2
  - [Salvar →] (`key: save_button`, verde quando nome não vazio) → persiste a pista e vai ao passo 4

### Painel 4 — SALVAR (Confirmação)

- **Saved row:** ícone ✓ (círculo verde) + nome da pista (Rajdhani 15px bold) + subtítulo "Linha de chegada · N setor(es)" (SpaceMono 11px, branco 28%)
- **Ação:** botão [INICIAR CORRIDA →] (verde, largura total) → fecha a tela

---

## Back button

Botão glass (ícone `arrow_back`, 44×44px) posicionado em overlay no canto superior esquerdo do mapa. Sempre visível. Sempre faz `Navigator.pop()`.

---

## Condição de salvo (_canSave)

```
_canSave = nome.isNotEmpty && centerlineClosed && startFinishD != null
```

O botão SALVAR só aparece no painel 3. Ao ser ativado, persiste a pista no `TrackRepository` e avança ao passo 4.

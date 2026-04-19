# Lapzy — Especificação de Telas

## 1. Tela Inicial
- Botão INICIAR centralizado e dominante (verde)
- Acesso rápido a: Histórico, Pistas, Ranking
- Login sugerido de forma não intrusiva (ícone de perfil)

## 2. Tela de Corrida ⚠️ CRÍTICA
- **Orientação**: landscape obrigatório
- **Montado no volante**: leitura a distância, sem toque necessário durante volta

### Layout
- Tempo atual da volta → fonte enorme, centro superior
- Delta (+ / -) → cor verde ou vermelho, bem visível
- Setores → indicadores visuais no rodapé (S1, S2, S3)
- Número de voltas → canto superior
- Melhor volta → canto inferior (roxo)

### Comportamento Visual
- Borda da tela muda de cor por evento:
  - Verde → delta positivo / PR
  - Roxo → melhor volta batida
  - Vermelho → alerta / encerrar
- Sem menus, sem navegação visível durante corrida
- Botão FINALIZAR: pequeno, canto inferior, requer confirmação

## 3. Seleção de Pista
- Lista de pistas salvas
- Botão "Nova Pista"
- Busca simples por nome

## 4. Criação de Pista
- Nome da pista
- Definir linha de chegada (GPS ou manual)
- Definir setores (opcional)
- Salvar com mínimo esforço (1 tela, sem wizard longo)

## 5. Resumo Pós-Corrida
- **Orientação**: portrait
- Salvar automático — sem ação do usuário necessária
- Sem botão Descartar

### Hero
- Melhor volta em destaque roxo (`#BF5AF2`) com badge PR
- Número da volta e total de voltas visíveis

### Resumo por setor
- Grade 3 colunas, N linhas (conforme número de setores da pista)
- Cada card exibe: label do setor, tempo médio da sessão, indicador melhor/pior/neutro
- Melhor setor: borda e label verde (`#00E676`)
- Pior setor: borda e label vermelho (`#FF3B30`)
- Insight textual abaixo da grade: setor com maior oportunidade de ganho + estimativa em segundos

### Lista de voltas
- Tempo total de cada volta
- Delta em relação à volta anterior (verde se melhorou, vermelho se piorou, "—" na primeira volta)
- Badge PR na melhor volta
- Toque em qualquer linha abre bottom sheet de detalhe

### Bottom sheet — detalhe de volta
- Exibe tempo total da volta e tempo individual por setor
- Coluna de comparação com label: **"SETOR CORRESPONDENTE NA MELHOR VOLTA"**
- Delta verde (▲) se o setor desta volta foi mais rápido que o setor correspondente da melhor volta
- Delta vermelho (▼) se foi mais lento
- Na própria melhor volta: todos os deltas exibem **▲ 0.000** em verde

### Ações
- Botão COMPARTILHAR único no rodapé

## 6. Histórico
- Lista de sessões por data
- Filtro por pista
- Requer login para sync na nuvem

## 7. Ranking
- Por pista
- Melhor volta de cada piloto
- Requer login

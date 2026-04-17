# Lapzy — App

> Cronometragem de kart para pilotos amadores. Feito para ser usado com o celular montado no volante.

## Sobre

Lapzy é um app Android de cronometragem para kartismo amador. O foco é na tela de corrida:
tempos de volta em tempo real, delta visual imediato, splits por setor e Personal Record com feedback de borda.

## Stack

- **Linguagem:** Dart
- **UI:** Flutter
- **Plataforma:** Android
- **Mapas:** Google Maps SDK (`google_maps_flutter`)
- **GPS:** `geolocator` (LocationAccuracy.best)
- **Assets:** `flutter_svg`

## Funcionalidades principais

- Tela de corrida em landscape obrigatório (montado no volante)
- Cronômetro de volta + delta em relação à melhor volta
- Splits por setor em tempo real (S1, S2, S3)
- Feedback de borda por evento (PR, melhor volta, volta pior)
- Criação de pista com Google Maps em dark mode
- Definição de setores por gesto ao longo do traçado (snap + linhas de corte automáticas)
- Resumo pós-corrida com análise por setor
- Histórico local offline-first

## Design

- Dark mode como padrão (`#0A0A0A` background)
- Landscape first na tela de corrida
- Tipografia Rajdhani (tempos) + Inter (textos)
- Paleta: verde `#00E676` · roxo `#BF5AF2` · vermelho `#FF3B30`

## Repositórios relacionados

- [lapzy-back](https://github.com/ricardobsilva/lapzy-back) — API e backend
- [lapzy-design](https://github.com/ricardobsilva/lapzy-design) — Design system e protótipos

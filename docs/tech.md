# Lapzy — Tecnologia

- Plataforma: Android
- Linguagem: Dart
- UI: Flutter
- Assets: SVG via `flutter_svg`

## Mapas

- Provedor: Google Maps SDK (Flutter — `google_maps_flutter`)
- Uso: Tela de criação de pista
- Motivo: melhor cobertura de imagem de satélite no Brasil, especialmente para pistas recentes
- Estilização: dark mode via JSON de estilo do Google Maps (`#0A0A0A` como base)
- Camadas: alternar entre satélite (posicionamento da linha de chegada) e mapa vetorial dark (navegação geral)

## GPS

- Package: `geolocator` (Flutter)
- Precisão: máxima disponível (`LocationAccuracy.best`)
- Uso: localização em tempo real na tela de corrida + centralizar mapa na criação de pista

## Geometria de Pista — Setores e Linhas de Corte

> Referência completa: `lapzy_criacao_pista_setores.md`
> Protótipo interativo: `lapzy_criacao_pista_setores_proto.html`

### Modelo de dados
- Pista armazenada como `List<LatLng>` (centerline GPS)
- Distâncias acumuladas pré-computadas via Haversine (metros)
- `Setor = { dStart: Double, dEnd: Double }` em metros ao longo do path
- `LinhaDeLargada = { d: Double }` — ponto único no path

### Algoritmos core
- **Snap**: projeção ortogonal de toque → segmento mais próximo → distância acumulada
- **Suavização**: mediana móvel (window=9) sobre distâncias brutas do gesto
- **Direção**: contagem de deltas crescentes vs decrescentes → detecta sentido da corrida
- **Tangente local**: lookahead de ±4px no path para suavidade em curvas
- **Normal perpendicular**: `perp(tangente) = (-tangente.y, tangente.x)`
- **Linhas de corte**: geradas em runtime a partir de `(pointAtDist, tangentAtDist, halfWidth)`

### Tolerâncias UX
- Snap radius: 45px (≈ 3–4m em escala de mapa típica)
- Comprimento mínimo de setor: 20m
- Wrap-around ignorado: deltas > 50% do comprimento total do circuito

### Conversão GPS ↔ pixels
- Projeção Mercator simples para distâncias < 5km
- `dStart`/`dEnd` sempre persistidos em metros reais (Haversine)
- Conversão para pixel apenas para renderização

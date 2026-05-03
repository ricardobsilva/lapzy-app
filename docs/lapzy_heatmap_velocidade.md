# Lapzy — Heatmap de Velocidade no Traçado

> Feature: `velocidade_tracado`  
> Tela: Resumo de corrida → Bottom sheet detalhe de volta  
> Status: Design aprovado, aguardando implementação

---

## O que é

Mapa de calor sobreposto ao traçado real da pista, exibido no bottom sheet de detalhe de volta. Mostra onde o piloto estava acelerando e onde estava freando ao longo do circuito, segmento a segmento.

Aparece abaixo da tabela de setores existente (SETOR / TEMPO / MELHOR VOLTA / DELTA).

---

## Onde vive na UI

```
Resumo de corrida
  └── Lista de voltas
        └── [toque em qualquer volta]
              └── Bottom sheet — detalhe de volta
                    ├── Header: "VOLTA N" + tempo + ref melhor volta
                    ├── Tabela: setor / tempo / melhor volta / delta   ← já existe
                    └── Seção: "VELOCIDADE NO TRAÇADO"                 ← NOVO
                          ├── Label + legenda (frenagem / aceleração)
                          └── Canvas com heatmap sobre mapa
```

---

## Dados de entrada

| Campo | Fonte | Detalhe |
|---|---|---|
| Centerline da pista | `Track.path: List<LatLng>` | Já salvo na criação da pista |
| Posições GPS da volta | `LapSample.points: List<LatLng>` | Coletado pelo `geolocator` durante a corrida |
| Timestamps | `LapSample.timestamps: List<DateTime>` | Um por ponto GPS |
| Setores | `Track.sectors: List<Sector>` | `{ dStart, dEnd }` em metros acumulados |

**Frequência GPS esperada:** 1–5 Hz (`LocationAccuracy.best`, Samsung A35). Resolução ~10–15m por sample a velocidade de kart. Suficiente para frenagem/aceleração por trecho, não para ponto exato de frenagem.

---

## Cálculo de velocidade

```dart
List<double> computeVelocityNorm(List<LatLng> points, List<DateTime> timestamps) {
  final velocities = <double>[];

  for (int i = 0; i < points.length - 1; i++) {
    final dist = Geolocator.distanceBetween(
      points[i].latitude, points[i].longitude,
      points[i+1].latitude, points[i+1].longitude,
    );
    final dt = timestamps[i+1].difference(timestamps[i]).inMilliseconds / 1000.0;
    velocities.add(dt > 0 ? dist / dt : 0.0);
  }
  velocities.add(velocities.last); // repete último ponto

  // normaliza 0..1
  final vMin = velocities.reduce(math.min);
  final vMax = velocities.reduce(math.max);
  final range = vMax - vMin;
  if (range < 0.001) return List.filled(velocities.length, 0.5);

  // suavização por mediana móvel (window = 9)
  return _smoothMedian(
    velocities.map((v) => (v - vMin) / range).toList(),
    window: 9,
  );
}

List<double> _smoothMedian(List<double> values, {int window = 9}) {
  final half = window ~/ 2;
  final n = values.length;
  return List.generate(n, (i) {
    final slice = values
        .sublist(math.max(0, i - half), math.min(n, i + half + 1))
      ..sort();
    return slice[slice.length ~/ 2];
  });
}
```

---

## Mapeamento de cor — `velColor`

Velocidade normalizada `v ∈ [0, 1]` → cor RGB.

```
v = 0.0  →  baixa velocidade  →  #FF3B30  (vermelho — frenagem)
v = 0.5  →  velocidade média  →  #888888  (cinza — transição)
v = 1.0  →  velocidade máxima →  #00E676  (verde — aceleração plena)
```

```dart
Color velColor(double v) {
  const brake = Color(0xFFFF3B30);
  const mid   = Color(0xFF888888);
  const accel = Color(0xFF00E676);

  if (v < 0.5) {
    return Color.lerp(brake, mid, v / 0.5)!;
  } else {
    return Color.lerp(mid, accel, (v - 0.5) / 0.5)!;
  }
}
```

> Não há "modo frenagem" ou "modo aceleração" na implementação — a cor já reflete o estado real de cada ponto. Os dois modos do protótipo eram para validação de design; na implementação, o heatmap é sempre o dado real da volta selecionada.

---

## Renderização — `TrackHeatmapPainter`

### Stacking de camadas (ordem de baixo para cima)

```
1. Google Maps widget (dark mode JSON)
2. Container(color: Colors.black.withOpacity(0.50))   ← overlay de contraste
3. CustomPaint(painter: TrackHeatmapPainter(...))      ← heatmap + linhas de corte
```

### CustomPainter

```dart
class TrackHeatmapPainter extends CustomPainter {
  final List<LatLng> centerline;     // centerline da pista
  final List<double> velocityNorm;   // v_norm por ponto GPS, já suavizado
  final List<Sector> sectors;        // setores com dStart/dEnd em metros
  final LatLngBounds bounds;         // bounding box para projeção
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    _drawHeatmap(canvas, size);
    _drawSectorCutLines(canvas, size);
  }

  void _drawHeatmap(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke;

    final pts = centerline.map((ll) => _project(ll, size)).toList();

    for (int i = 0; i < pts.length - 1; i++) {
      paint.color = velColor(velocityNorm[i]).withOpacity(0.92);
      canvas.drawLine(pts[i], pts[i + 1], paint);
    }
  }

  void _drawSectorCutLines(Canvas canvas, Size size) {
    // pré-computa distâncias acumuladas do centerline
    final cumDist = _buildCumDist(centerline);
    final totalLen = cumDist.last;

    for (final sector in sectors) {
      for (final d in [sector.dStart, sector.dEnd]) {
        final center = _pointAtDist(d, centerline, cumDist, size);
        final tangent = _tangentAtDist(d, centerline, cumDist, size);
        final normal = Offset(-tangent.dy, tangent.dx);
        final half = 9.0 / 2 + 5;

        final p1 = center + normal * half;
        final p2 = center - normal * half;

        // glow
        canvas.drawLine(p1, p2, Paint()
          ..color = sector.color.withOpacity(0.20)
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round);

        // linha tracejada
        _drawDashed(canvas, p1, p2, sector.color.withOpacity(0.90), 1.5, [3, 3]);

        // dots nas extremidades
        final dotPaint = Paint()..color = sector.color..style = PaintingStyle.fill;
        canvas.drawCircle(p1, 2.5, dotPaint);
        canvas.drawCircle(p2, 2.5, dotPaint);
      }

      // label do setor
      final midD = (sector.dStart + sector.dEnd) / 2;
      final midPt = _pointAtDist(midD, centerline, cumDist, size);
      final radial = (midPt - _canvasCenter(size));
      final labelPos = midPt + radial / radial.distance * 15;
      _drawLabel(canvas, labelPos, sector.label, sector.color);
    }
  }

  // Projeção Mercator simples (< 5km, suficiente para pistas de kart)
  Offset _project(LatLng ll, Size size) {
    final x = (ll.longitude - bounds.southwest.longitude) /
               (bounds.northeast.longitude - bounds.southwest.longitude) * size.width;
    final y = (1 - (ll.latitude - bounds.southwest.latitude) /
               (bounds.northeast.latitude - bounds.southwest.latitude)) * size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(TrackHeatmapPainter old) =>
    old.velocityNorm != velocityNorm || old.sectors != sectors;
}
```

---

## Performance

| Preocupação | Solução |
|---|---|
| Repaint desnecessário do mapa | `RepaintBoundary` envolvendo o `CustomPaint` |
| Cálculo pesado no paint() | Pre-computar `List<Color>` no `initState` / ao abrir o sheet |
| Muitos segmentos | ~60–300 pontos por volta típica a 1Hz — sem problema |
| Dados insuficientes | Se `points.length < 10`: exibir `"dados insuficientes para esta volta"` no lugar do canvas |

---

## Fallback — dados insuficientes

```dart
if (lapSamples.length < 10) {
  return Center(
    child: Text(
      'dados insuficientes',
      style: TextStyle(
        color: Colors.white24,
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
```

---

## Cores dos setores — linhas de corte

| Setor | Cor | Hex |
|---|---|---|
| S1 | Azul | `#00B0FF` |
| S2 | Amarelo | `#FFD600` |
| S3 | Laranja | `#FF6D00` |

> `#FF6D00` aqui é **dado de setor**, não elemento de marca. A regra "orange é só brand" não se aplica às cores de setor — ver `identidade.md`.

---

## Linha de largada (S/C)

Linha branca sólida perpendicular ao centerline no ponto `Track.startFinish.d`.

```dart
// mesma lógica das linhas de corte de setor, mas:
paint.color = Colors.white.withOpacity(0.85);
paint.strokeWidth = 2.0;
// sem tracejado — linha sólida
```

---

## Referências cruzadas

- `lapzy_criacao_pista_setores.md` — algoritmos de snap, `pointAtDist`, `tangentAtDist`, `cutLine`
- `tech.md` — modelo de dados da pista, GPS, Haversine
- `identidade.md` — cores dos setores vs cores de marca
- `telas.md` — spec da tela de resumo pós-corrida e bottom sheet

# Lapzy — Sistema de Setores e Linha de Largada
> **Referência cruzada:** este arquivo documenta a lógica de geometria e UX da tela de criação de pista.
> Arquivos relacionados: `lapzy_tela_criacao_pista.md` · `tech.md`

---

## Decisões fechadas

### Modelo de dados do setor

O setor **não é um desenho** — é um intervalo contínuo do path oficial da pista.

```
Setor = { id, dStart, dEnd, color }
```

- `dStart` e `dEnd` são distâncias acumuladas em metros ao longo do centerline
- Exemplo: S1 = do metro 0 ao metro 420
- O desenho visual é gerado a partir desse intervalo, não armazenado
- Nunca persistir polylines ou coordenadas brutas do gesto do usuário

### Modelo de dados da linha de largada (S/C)

```
LinhaDeLargada = { dStart: number }  // ponto único no path
```

- É um ponto no centerline, não um intervalo
- A linha visual (perpendicular, edge-to-edge) é calculada na hora da renderização

---

## Comportamento UX — Setores

1. Usuário seleciona o modo (S1 / S2 / S3)
2. Usuário arrasta o dedo **ao longo da pista** (não desenha livremente)
3. O sistema projeta cada ponto do gesto para a distância acumulada mais próxima no path
4. Suavização por mediana móvel elimina jitter
5. O sistema detecta a direção do gesto (sentido da corrida)
6. O intervalo `[dStart, dEnd]` é extraído
7. O trecho do path entre `dStart` e `dEnd` é destacado visualmente como banda colorida
8. Duas linhas de corte perpendiculares aparecem automaticamente nas extremidades

**O usuário nunca desenha a linha de corte manualmente.**

### O que rejeitar / corrigir

| Situação | Comportamento |
|---|---|
| Gesto a > 45px da pista | Ignorar ponto, não adicionar à coleta |
| Comprimento < 20m | Rejeitar intervalo, pedir novo gesto |
| Gesto no sentido inverso | Inverter `dStart`/`dEnd` automaticamente |
| Wrap-around (salto > 50% do circuito) | Ignorar delta, tratar como noise |

---

## Comportamento UX — Linha de largada (S/C)

1. Usuário toca qualquer ponto sobre a pista
2. O sistema faz snap para o ponto mais próximo do centerline
3. A linha perpendicular aparece automaticamente (sem arrastar)
4. Marcador S/C é posicionado **fora** da linha (offset lateral) para não ocultá-la
5. Reposicionamento: novo toque em outro ponto da pista

---

## Lógica geométrica

### Distâncias acumuladas

```typescript
// Pré-computado uma vez ao carregar a pista
const cumDist = [0];
for (let i = 1; i < path.length; i++) {
  cumDist.push(cumDist[i-1] + len(sub(path[i], path[i-1])));
}
const TOTAL_LEN = cumDist[cumDist.length - 1];
```

### Snap: toque → distância acumulada

```typescript
function snapToDist(P: Vec2, path: Vec2[], cumDist: number[]): { d: number, screenDist: number } {
  let bestDist = Infinity, bestD = 0;
  for (let i = 0; i < path.length - 1; i++) {
    const A = path[i], B = path[i+1];
    const AB = sub(B, A), AP = sub(P, A);
    const t = clamp(dot(AP, AB) / dot(AB, AB), 0, 1);
    const proj = add(A, scale(AB, t));
    const dist = len(sub(P, proj));
    if (dist < bestDist) {
      bestDist = dist;
      bestD = cumDist[i] + t * (cumDist[i+1] - cumDist[i]);
    }
  }
  return { d: bestD, screenDist: bestDist };
}
```

### Suavização por mediana móvel

```typescript
// Prefira mediana sobre média: ignora outliers sem distorcer o intervalo
function smoothByMedian(dists: number[], window = 9): number[] {
  const half = Math.floor(window / 2);
  return dists.map((_, i) => {
    const slice = dists.slice(Math.max(0, i-half), i+half+1).sort((a,b) => a-b);
    return slice[Math.floor(slice.length / 2)];
  });
}
```

### Detecção de direção

```typescript
function detectDirection(dists: number[], totalLen: number): 'forward' | 'backward' {
  let growing = 0, shrinking = 0;
  for (let i = 1; i < dists.length; i++) {
    const delta = dists[i] - dists[i-1];
    if (Math.abs(delta) < totalLen * 0.4) { // ignora wrap-around
      if (delta > 0) growing++; else shrinking++;
    }
  }
  return growing >= shrinking ? 'forward' : 'backward';
}
```

### Ponto e tangente a uma distância acumulada

```typescript
function pointAtDist(d: number, path: Vec2[], cumDist: number[]): Vec2 {
  d = ((d % TOTAL_LEN) + TOTAL_LEN) % TOTAL_LEN;
  for (let i = 1; i < cumDist.length; i++) {
    if (cumDist[i] >= d) {
      const t = (d - cumDist[i-1]) / (cumDist[i] - cumDist[i-1]);
      return lerp(path[i-1], path[i], t);
    }
  }
  return path[path.length - 1];
}

function tangentAtDist(d: number, path: Vec2[], cumDist: number[]): Vec2 {
  const DELTA = 4; // px lookahead para suavidade
  const pA = pointAtDist(d - DELTA, path, cumDist);
  const pB = pointAtDist(d + DELTA, path, cumDist);
  return normalize(sub(pB, pA));
}
```

### Linha de corte perpendicular automática

```typescript
function cutLine(d: number, path: Vec2[], cumDist: number[], halfWidth: number) {
  const center  = pointAtDist(d, path, cumDist);
  const tangent = tangentAtDist(d, path, cumDist);
  const normal  = perp(tangent); // perp(v) = (-v.y, v.x)
  return {
    pA: add(center, scale(normal,  halfWidth + 2)), // borda externa
    pB: add(center, scale(normal, -halfWidth - 2)), // borda interna
    center
  };
}
```

### Subpath entre dois pontos (para highlight visual)

```typescript
function subpath(dStart: number, dEnd: number, path: Vec2[], cumDist: number[]): Vec2[] {
  const pts: Vec2[] = [];
  const step = 2; // resolução em px
  let d = dStart;
  while (true) {
    pts.push(pointAtDist(d, path, cumDist));
    const remaining = ((dEnd - d) + TOTAL_LEN) % TOTAL_LEN;
    if (remaining < step) { pts.push(pointAtDist(dEnd, path, cumDist)); break; }
    d = (d + step) % TOTAL_LEN;
  }
  return pts;
}
```

---

## Implementação Kotlin (Flutter/Android nativo)

```kotlin
data class Vec2(val x: Double, val y: Double) {
  operator fun plus(o: Vec2)  = Vec2(x+o.x, y+o.y)
  operator fun minus(o: Vec2) = Vec2(x-o.x, y-o.y)
  operator fun times(s: Double) = Vec2(x*s, y*s)
  fun len()  = sqrt(x*x + y*y)
  fun norm() = if (len() < 1e-9) Vec2(0.0,0.0) else this * (1.0/len())
  fun perp() = Vec2(-y, x)
  fun dot(o: Vec2) = x*o.x + y*o.y
}

fun snapToDist(P: Vec2, path: List<Vec2>, cumDist: List<Double>): Double {
  var bestDist = Double.MAX_VALUE
  var bestD = 0.0
  for (i in 0 until path.size - 1) {
    val A = path[i]; val B = path[i+1]
    val AB = B - A;  val AP = P - A
    val t = (AP.dot(AB) / AB.dot(AB)).coerceIn(0.0, 1.0)
    val proj = A + AB * t
    val dist = (P - proj).len()
    if (dist < bestDist) {
      bestDist = dist
      bestD = cumDist[i] + t * (cumDist[i+1] - cumDist[i])
    }
  }
  return bestD
}

fun distToSector(rawDists: List<Double>, totalLen: Double): Pair<Double,Double>? {
  if (rawDists.size < 2) return null
  val smoothed = rawDists.mapIndexed { i, _ ->
    val slice = rawDists.subList(maxOf(0, i-4), minOf(rawDists.size, i+5)).sorted()
    slice[slice.size / 2]
  }
  var growing = 0; var shrinking = 0
  for (i in 1 until smoothed.size) {
    val delta = smoothed[i] - smoothed[i-1]
    if (abs(delta) < totalLen * 0.4) { if (delta > 0) growing++ else shrinking++ }
  }
  var dStart = smoothed.first()
  var dEnd   = smoothed.last()
  if (shrinking > growing) { val tmp = dStart; dStart = dEnd; dEnd = tmp }
  val len = ((dEnd - dStart) + totalLen) % totalLen
  return if (len < 20.0) null else Pair(dStart, dEnd)
}
```

---

## Conversão GPS real (LatLng → metros)

```kotlin
fun haversine(a: LatLng, b: LatLng): Double {
  val R = 6371000.0
  val dLat = Math.toRadians(b.latitude - a.latitude)
  val dLon = Math.toRadians(b.longitude - a.longitude)
  val h = sin(dLat/2).pow(2) +
    cos(Math.toRadians(a.latitude)) *
    cos(Math.toRadians(b.latitude)) *
    sin(dLon/2).pow(2)
  return 2 * R * asin(sqrt(h))
}

// O centerline da pista é uma List<LatLng> do Google Maps
// cumDist é buildado com haversine entre pontos consecutivos
// dStart/dEnd persistidos em metros reais
// Na renderização: converte de volta para LatLng com pointAtDist
```

---

## Visual das linhas de corte

| Elemento | Especificação |
|---|---|
| Glow de fundo | Cor do setor, stroke-width 20, opacidade 7% |
| Borda tracejada | Cor do setor, dash 4/4, stroke-width 1.8, opacidade 50% |
| Linha sólida | Cor do setor, stroke-width 3, opacidade 100% |
| Caps nas extremidades | Círculo r=4, fill cor do setor, stroke preto 1.5px |
| Largura de detecção | `TRACK_HALFWIDTH + 2` px além de cada borda |

---

## Protótipo interativo

Ver arquivo `lapzy_criacao_pista_setores_proto.html` para demo completa e funcional com:
- Centerline paramétrico com chicane
- Snap em tempo real durante o arraste
- Suavização por mediana móvel
- Detecção de direção automática
- Linhas de corte perpendiculares geradas automaticamente
- Highlight do trecho selecionado
- Info panel com dStart/dEnd/comprimento em tempo real

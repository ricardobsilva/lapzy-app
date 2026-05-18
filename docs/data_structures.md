# Lapzy — Estrutura de Dados para Contrato de API

> **Finalidade**: Este documento descreve todas as entidades, enums, eventos e relacionamentos de dados do app Lapzy. Serve como insumo para a definição dos contratos da REST API.

---

## Sumário

1. [Entidades Principais](#1-entidades-principais)
   - [GeoPoint](#geopoint)
   - [TrackLine](#trackline)
   - [Track](#track)
   - [LapResult](#lapresult)
   - [RaceSessionRecord](#racesessionrecord)
2. [Enums](#2-enums)
   - [RaceEventState](#raceeventstate)
3. [Estado ao Vivo (não persistido)](#3-estado-ao-vivo-não-persistido)
   - [RaceSessionSnapshot](#racesessionsnapshot)
4. [Eventos de GPS (streaming)](#4-eventos-de-gps-streaming)
5. [Relacionamentos](#5-relacionamentos)
6. [Persistência Local](#6-persistência-local)
7. [Recursos REST Esperados](#7-recursos-rest-esperados)
8. [Exemplos de Payload JSON](#8-exemplos-de-payload-json)
9. [Decisões de Design para a API](#9-decisões-de-design-para-a-api)

---

## 1. Entidades Principais

### GeoPoint

Coordenada geográfica genérica. Agnóstica de plataforma (não depende de `google_maps_flutter`).

| Campo | Tipo     | Obrigatório | Descrição           |
|-------|----------|-------------|---------------------|
| `lat` | `double` | sim         | Latitude decimal    |
| `lng` | `double` | sim         | Longitude decimal   |

---

### TrackLine

Linha transversal no traçado — usada tanto para a linha de largada/chegada quanto para os divisores de setor. Suporta trajetórias curvas via pontos intermediários.

| Campo          | Tipo          | Obrigatório | Descrição                                                      |
|----------------|---------------|-------------|----------------------------------------------------------------|
| `a`            | `GeoPoint`    | sim         | Ponto inicial da linha                                         |
| `b`            | `GeoPoint`    | sim         | Ponto final da linha                                           |
| `middlePoints` | `GeoPoint[]`  | sim         | Pontos intermediários para linhas curvas (pode ser array vazio)|
| `widthMeters`  | `double`      | sim         | Largura da zona de detecção GPS em metros (range: 3–30, default: 6) |

**Campos computados (não persistidos, não enviados à API)**:
- `allPoints` — concatenação de `a + middlePoints + b`
- `midpoint` — centróide geográfico da linha

---

### Track

Traçado completo com layout de setores e linha de largada/chegada.

| Campo               | Tipo           | Obrigatório | Descrição                                                                            |
|---------------------|----------------|-------------|--------------------------------------------------------------------------------------|
| `id`                | `string`       | sim         | UUID v4 gerado pelo cliente                                                          |
| `name`              | `string`       | sim         | Nome do kartódromo                                                                   |
| `startFinishLine`   | `TrackLine?`   | não         | Linha de largada/chegada (`null` enquanto o traçado ainda está sendo configurado)    |
| `sectorBoundaries`  | `TrackLine[]`  | sim         | Divisores de setor. N divisores definem N+1 setores. Array vazio = sem setores       |
| `lastSession`       | `datetime?`    | não         | Data/hora da última corrida neste traçado (ISO 8601, UTC)                            |
| `createdAt`         | `datetime`     | sim         | Timestamp de criação (ISO 8601, UTC) — usado para resolução de conflito em sync      |
| `updatedAt`         | `datetime`     | sim         | Timestamp da última atualização (ISO 8601, UTC) — usado para resolução de conflito   |
| `shareCode`         | `string?`      | não         | Código de compartilhamento gerado pelo servidor via `POST /tracks/:id/share`. Nunca gerado pelo cliente. `null` se o traçado nunca foi compartilhado. |
| `importedFrom`      | `string?`      | não         | `shareCode` do traçado de origem quando este traçado foi importado. Imutável após criação. `null` se criado localmente. |

**Regra de setores**: `sectorBoundaries.length == 0` → corrida sem setores; `sectorBoundaries.length == 2` → 3 setores (S1, S2, S3).

**Regra de compartilhamento**: `shareCode` é sempre gerado pelo servidor — nunca pelo app. O app nunca envia `shareCode` em `POST /tracks`; o campo é ignorado se presente. Um traçado importado tem `importedFrom` preenchido e `shareCode == null` até que o novo dono o compartilhe novamente.

---

### LapResult

Registro imutável de uma volta completada. Sempre embutido dentro de `RaceSessionRecord` — não existe como recurso independente na API.

| Campo     | Tipo     | Obrigatório | Descrição                                                                                       |
|-----------|----------|-------------|-------------------------------------------------------------------------------------------------|
| `lapMs`   | `int`    | sim         | Tempo total da volta em milissegundos                                                           |
| `sectors` | `int?[]` | sim         | Tempos por setor em ms, indexados por posição (`sectors[0]` = S1, `sectors[1]` = S2, etc.). Elemento `null` indica setor não definido no traçado no momento da volta |

**Invariante**: quando todos os elementos de `sectors` são não-nulos, `sum(sectors) == lapMs`.

---

### GpsDevice

Informações do dispositivo usado como GPS na corrida. Coletado via `device_info_plus` ao encerrar a corrida. Embutido em `RaceSessionRecord` — não existe como recurso independente.

| Campo           | Tipo     | Obrigatório | Descrição                                                                  |
|-----------------|----------|-------------|----------------------------------------------------------------------------|
| `manufacturer`  | `string` | sim         | Fabricante do dispositivo (ex: `"Samsung"`)                                |
| `model`         | `string` | sim         | Modelo do dispositivo (ex: `"SM-A356B"`)                                   |
| `androidVersion`| `string` | sim         | Versão do Android (ex: `"14"`)                                             |
| `accuracyLabel` | `string` | sim         | Rótulo de precisão pré-calculado para exibição ao usuário                  |

**Perfis de precisão**:
- `consumer` → "GPS de smartphone · Precisão típica: ±300–500ms"
- `premium` → "GPS de smartphone premium · Precisão típica: ±100–300ms"

Qualquer modelo não mapeado usa `consumer` como fallback.

---

### RaceSessionRecord

Registro histórico persistido de uma sessão de corrida completa. Criado ao final de cada corrida.

| Campo        | Tipo           | Obrigatório | Descrição                                                                                      |
|--------------|----------------|-------------|-----------------------------------------------------------------------------------------------|
| `id`         | `string`       | sim         | UUID v4 gerado pelo cliente no momento de encerramento da corrida                             |
| `trackId`    | `string`       | sim         | FK para `Track.id`. Preservado mesmo se o traçado for deletado posteriormente                 |
| `trackName`  | `string`       | sim         | Nome do traçado desnormalizado — garante legibilidade histórica mesmo após deleção do traçado |
| `date`       | `datetime`     | sim         | Data/hora de início da corrida (ISO 8601, UTC)                                                |
| `laps`       | `LapResult[]`  | sim         | Todas as voltas completadas, em ordem cronológica                                             |
| `bestLapMs`  | `int?`         | não         | Melhor volta da sessão em ms. `null` se nenhuma volta foi completada                          |
| `createdAt`  | `datetime`     | sim         | Timestamp de criação do registro (ISO 8601, UTC) — usado para deduplicação e sync             |
| `gpsDevice`  | `GpsDevice?`   | não         | Dispositivo usado como GPS. `null` em sessões salvas antes da TASK-023 — compatibilidade retroativa garantida |

---

## 2. Enums

### RaceEventState

Estado visual calculado após o cruzamento da linha de chegada. Determina feedback visual ao piloto (cor da borda, animação).

| Valor            | Significado                                                                          |
|------------------|--------------------------------------------------------------------------------------|
| `neutral`        | Corrida iniciada, nenhuma volta completada ainda                                     |
| `melhorVolta`    | Primeira melhor volta da sessão (sem comparativo anterior)                           |
| `voltaMelhor`    | Nova melhor volta — mais rápida que todas as anteriores da sessão                    |
| `voltaPior`      | Volta mais lenta que a melhor volta da sessão                                        |
| `personalRecord` | Nova melhor volta, superando um threshold histórico (recorde pessoal)                |

**Nota**: Este enum é calculado em tempo de execução no app e **não precisa ser enviado à API**. É derivável a partir dos dados de `laps` e de um threshold de recorde pessoal.

---

## 3. Estado ao Vivo (não persistido)

### RaceSessionSnapshot

Snapshot imutável do estado durante a corrida ativa. Existe apenas em memória enquanto a corrida está em andamento. **Não é enviado à API.**

| Campo            | Tipo              | Descrição                                                                       |
|------------------|-------------------|---------------------------------------------------------------------------------|
| `currentLapMs`   | `int`             | Timer da volta atual em ms (atualizado a cada tick do timer de UI)              |
| `lapNumber`      | `int`             | Número da volta atual (começa em 1 após o primeiro cruzamento)                  |
| `bestLapMs`      | `int?`            | Melhor volta da sessão (`null` até a primeira volta ser completada)             |
| `deltaMs`        | `int?`            | Delta vs referência em ms (positivo = mais rápido, negativo = mais lento, `null` = sem referência) |
| `eventState`     | `RaceEventState`  | Estado visual atual                                                             |
| `currentSectors` | `int?[]`          | Tempos de setor da volta em andamento (`null` = setor ainda não cruzado)        |
| `completedLaps`  | `LapResult[]`     | Voltas já finalizadas na sessão corrente                                        |

---

## 4. Eventos de GPS (streaming)

Emitidos pelo `LapDetector` em tempo real durante a corrida. **Não persistidos, não enviados à API.**

### LapCrossedEvent

Cruzamento válido da linha de largada/chegada detectado.

| Campo       | Tipo       | Descrição                                         |
|-------------|------------|---------------------------------------------------|
| `timestamp` | `datetime` | Timestamp interpolado da travessia da linha (GPS) |

### LapCrossedSuspectEvent

Cruzamento detectado, mas tempo de volta é estatisticamente suspeito (outlier).

| Campo       | Tipo       | Descrição                                                       |
|-------------|------------|-----------------------------------------------------------------|
| `timestamp` | `datetime` | Timestamp interpolado da travessia                              |
| `lapMs`     | `int`      | Tempo calculado da volta suspeita                               |
| `medianMs`  | `int`      | Mediana das últimas voltas válidas (base de comparação usada)   |

### SectorCrossedEvent

Cruzamento de divisor de setor detectado.

| Campo         | Tipo       | Descrição                                                        |
|---------------|------------|------------------------------------------------------------------|
| `sectorIndex` | `int`      | Índice 0-based do setor cruzado (0 = S1, 1 = S2, 2 = S3, etc.) |
| `timestamp`   | `datetime` | Timestamp interpolado da travessia                               |

---

## 5. Relacionamentos

```
Track (1) ──────────────────────────── (N) RaceSessionRecord
  │                                           │
  ├── id: UUID v4                             ├── id: UUID v4
  ├── name: string                            ├── trackId → Track.id
  ├── startFinishLine: TrackLine?             ├── trackName: string (desnormalizado)
  │     ├── a: GeoPoint                       ├── date: datetime
  │     ├── b: GeoPoint                       ├── bestLapMs: int?
  │     └── middlePoints: GeoPoint[]          ├── createdAt: datetime
  │                                           ├── gpsDevice: GpsDevice?  ← TASK-023
  ├── sectorBoundaries: TrackLine[]           │     ├── manufacturer: string
  │     (mesma estrutura de TrackLine)        │     ├── model: string
  │                                           │     ├── androidVersion: string
  ├── shareCode: string?   ← TASK-024         │     └── accuracyLabel: string
  └── importedFrom: string? ← TASK-024        └── laps: LapResult[]
                                                    ├── lapMs: int
                                                    └── sectors: int?[]
```

**Cardinalidade**:
- 1 `Track` → N `RaceSessionRecord`
- 1 `RaceSessionRecord` → N `LapResult` (embutido, sem ID próprio)
- 1 `TrackLine` → 1 par de `GeoPoint` + N `GeoPoint` intermediários

---

## 6. Persistência Local

Atualmente o app persiste dados via **SharedPreferences** (chave-valor, JSON serializado).

| Chave SharedPreferences | Conteúdo                        | Formato              |
|-------------------------|---------------------------------|----------------------|
| `lapzy_tracks_v1`       | Todos os traçados do usuário    | `JSON array` de `Track` |
| `lapzy_sessions_v1`     | Histórico de corridas           | `JSON array` de `RaceSessionRecord` |

**Estratégia de migração**: o sufixo `_v1` nos nomes das chaves foi reservado para permitir migrações sem breaking change.

---

## 7. Recursos REST Esperados

### Traçados

| Método   | Endpoint           | Descrição                            | Payload Request | Payload Response  |
|----------|--------------------|--------------------------------------|-----------------|-------------------|
| `GET`    | `/tracks`          | Lista todos os traçados              | —               | `Track[]`         |
| `GET`    | `/tracks/:id`      | Busca traçado por ID                 | —               | `Track`           |
| `POST`   | `/tracks`          | Cria novo traçado (ID gerado pelo cliente) | `Track`    | `Track`           |
| `PUT`    | `/tracks/:id`      | Atualiza traçado existente           | `Track`         | `Track`           |
| `DELETE` | `/tracks/:id`      | Remove traçado                       | —               | `204 No Content`  |

### Sessões de Corrida

| Método   | Endpoint                        | Descrição                                   | Payload Request       | Payload Response        |
|----------|---------------------------------|---------------------------------------------|-----------------------|-------------------------|
| `GET`    | `/sessions`                     | Lista todas as sessões do usuário           | —                     | `RaceSessionRecord[]`   |
| `GET`    | `/sessions/:id`                 | Busca sessão por ID                         | —                     | `RaceSessionRecord`     |
| `GET`    | `/sessions?trackId=:trackId`    | Lista sessões de um traçado específico      | —                     | `RaceSessionRecord[]`   |
| `POST`   | `/sessions`                     | Salva sessão (ID gerado pelo cliente)       | `RaceSessionRecord`   | `RaceSessionRecord`     |
| `DELETE` | `/sessions/:id`                 | Remove sessão                               | —                     | `204 No Content`        |

### Agregações (candidatos — a definir)

| Método | Endpoint                            | Descrição                                          |
|--------|-------------------------------------|----------------------------------------------------|
| `GET`  | `/tracks/:id/best-lap`              | Melhor volta histórica no traçado (threshold de PR)|
| `GET`  | `/sessions?trackId=:id&limit=N`     | Últimas N sessões de um traçado                    |

---

## 8. Exemplos de Payload JSON

### Track

```json
{
  "id": "a1b2c3d4-0001-4000-8000-seed00000001",
  "name": "Granja Viana",
  "startFinishLine": {
    "a": { "lat": -23.5890, "lng": -46.9210 },
    "b": { "lat": -23.5895, "lng": -46.9205 },
    "middlePoints": [],
    "widthMeters": 6.0
  },
  "sectorBoundaries": [
    {
      "a": { "lat": -23.5900, "lng": -46.9220 },
      "b": { "lat": -23.5905, "lng": -46.9215 },
      "middlePoints": [],
      "widthMeters": 6.0
    },
    {
      "a": { "lat": -23.5910, "lng": -46.9230 },
      "b": { "lat": -23.5915, "lng": -46.9225 },
      "middlePoints": [],
      "widthMeters": 6.0
    }
  ],
  "lastSession": "2026-05-01T14:30:00Z",
  "createdAt": "2026-01-15T10:00:00Z",
  "updatedAt": "2026-05-01T14:30:00Z"
}
```

### RaceSessionRecord

```json
{
  "id": "b2c3d4e5-0001-4000-8000-seed00000001",
  "trackId": "a1b2c3d4-0001-4000-8000-seed00000001",
  "trackName": "Granja Viana",
  "date": "2026-05-01T14:30:00Z",
  "bestLapMs": 54890,
  "createdAt": "2026-05-01T16:45:00Z",
  "gpsDevice": {
    "manufacturer": "Samsung",
    "model": "SM-A356B",
    "androidVersion": "14",
    "accuracyLabel": "GPS de smartphone · Precisão típica: ±300–500ms"
  },
  "laps": [
    { "lapMs": 58200, "sectors": [22100, 19800, 16300] },
    { "lapMs": 55640, "sectors": [21500, 18900, 15240] },
    { "lapMs": 54890, "sectors": [21270, 18460, 15160] },
    { "lapMs": 55120, "sectors": [21400, 18600, 15120] }
  ]
}
```

### Track com campos de compartilhamento

```json
{
  "id": "a1b2c3d4-0001-4000-8000-seed00000001",
  "name": "Granja Viana",
  "startFinishLine": {
    "a": { "lat": -23.5890, "lng": -46.9210 },
    "b": { "lat": -23.5895, "lng": -46.9205 },
    "middlePoints": [],
    "widthMeters": 6.0
  },
  "sectorBoundaries": [ ... ],
  "lastSession": "2026-05-01T14:30:00Z",
  "createdAt": "2026-01-15T10:00:00Z",
  "updatedAt": "2026-05-01T14:30:00Z",
  "shareCode": "GV7K2M",
  "importedFrom": null
}
```

### Track importado de outro piloto

```json
{
  "id": "f9e8d7c6-nova-uuid-gerada-localmente",
  "name": "Granja Viana",
  "startFinishLine": { ... },
  "sectorBoundaries": [ ... ],
  "lastSession": null,
  "createdAt": "2026-05-10T10:00:00Z",
  "updatedAt": "2026-05-10T10:00:00Z",
  "shareCode": null,
  "importedFrom": "GV7K2M"
}
```

### Traçado sem setores definidos

```json
{
  "id": "c3d4e5f6-0001-4000-8000-seed00000001",
  "name": "Pista Nova",
  "startFinishLine": null,
  "sectorBoundaries": [],
  "lastSession": null,
  "createdAt": "2026-05-09T10:00:00Z",
  "updatedAt": "2026-05-09T10:00:00Z"
}
```

### Sessão com setor nulo (traçado sem S3 no momento da corrida)

```json
{
  "id": "d4e5f6a7-0001-4000-8000-seed00000001",
  "trackId": "c3d4e5f6-0001-4000-8000-seed00000001",
  "trackName": "Pista Nova",
  "date": "2026-05-09T10:00:00Z",
  "bestLapMs": 62400,
  "createdAt": "2026-05-09T11:30:00Z",
  "laps": [
    { "lapMs": 62400, "sectors": [24100, 20300, null] },
    { "lapMs": 63100, "sectors": [24500, 20600, null] }
  ]
}
```

---

## 9. Decisões de Design para a API

### IDs gerados pelo cliente

O app gera UUIDs v4 localmente antes de enviar à API. A API deve:
- Aceitar o `id` fornecido no body (upsert por ID)
- Retornar `409 Conflict` se o ID já existir para outro usuário
- **Não** gerar um novo ID no servidor

**Motivo**: o app opera offline-first. O ID precisa existir localmente antes de qualquer sync com a API.

### Campos `sectors` com elementos nulos

`sectors` é um array que pode conter elementos `null`. Isso ocorre quando o traçado não tinha um determinado setor definido no momento da corrida.

A API deve:
- Aceitar e retornar `null` como valor válido em qualquer posição do array
- Não interpretar `null` como ausência do campo — ele é intencional

### `trackName` desnormalizado

`RaceSessionRecord.trackName` repete o nome do traçado intencionalmente. Garante que o histórico de corridas permaneça legível se o traçado for deletado da API.

A API não deve rejeitar `trackName` como redundante — ele é parte do contrato.

### Timestamps em UTC, ISO 8601

Todos os campos de data/hora (`date`, `createdAt`, `updatedAt`, `lastSession`) devem ser:
- Formato: `YYYY-MM-DDTHH:mm:ssZ` (ISO 8601, UTC)
- Sem timezone offset local — sempre UTC

### Sincronização offline-first

O app funciona completamente sem internet. A estratégia de sync deve ser:

1. **Last-write-wins por `updatedAt`** para `Track`
2. **Append-only por `id`** para `RaceSessionRecord` (sessões não são editadas, apenas criadas ou deletadas)
3. `createdAt` é imutável após criação — nunca atualizado pelo servidor

### `LapResult` como valor embutido

`LapResult` não tem ID próprio e não existe como recurso independente. É sempre tratado como parte do `RaceSessionRecord`. A API não deve expor `/laps` como endpoint separado.

### Ordenação padrão

- `GET /tracks` → ordenar por `updatedAt DESC`
- `GET /sessions` → ordenar por `date DESC`
- `laps[]` dentro de `RaceSessionRecord` → sempre em ordem cronológica (índice 0 = primeira volta)

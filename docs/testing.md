# Lapzy — Estratégia de Testes

## Filosofia

Testes no Lapzy seguem uma regra única e inegociável:
**cada teste é completamente independente de qualquer outro.**

Isso significa:
- Nenhum teste depende de estado deixado por outro teste
- Nenhum setup compartilhado entre suites ou arquivos
- Nenhum método auxiliar que inicializa contexto global
- Nenhum `setUp` / `tearDown` compartilhado entre classes de teste
- Cada teste cria tudo que precisa, usa, e descarta

Se um teste não consegue rodar sozinho em qualquer ordem, ele está errado.

---

## Camadas de Teste

### 1. Unitário (`test/unit/`)
- Testa lógica pura: funções, classes, algoritmos
- Sem Flutter, sem widgets, sem dispositivo
- Exemplos no Lapzy: cálculo de delta, haversine, snap de setor, detecção de direção, mediana móvel
- Roda com: `flutter test test/unit/`

### 2. Widget (`test/widget/`)
- Testa widgets isolados: renderização, estados, interações
- Sem dispositivo real, usa `WidgetTester`
- Exemplos no Lapzy: botão INICIAR renderiza com cor correta, logo bicolor, hint visível
- Roda com: `flutter test test/widget/`

### 3. Integração (`test/integration/`)
- Testa o app completo em dispositivo ou emulador real
- Simula o usuário navegando, tocando, vendo resultados
- **Tão obrigatório quanto unitário e widget — não é opcional**
- Exemplos no Lapzy: fluxo completo home → seleção de pista → corrida → resumo
- Roda com: `flutter test integration_test/ -d <device_id>`

---

## Cobertura por US

Cada US entregue deve ter testes nas três camadas cobrindo:
- Todos os critérios de aceite definidos na spec
- Todos os cenários mapeados (happy path + edge cases)
- Todos os estados visuais relevantes (vazio, preenchido, erro)

Nenhuma task transita para Done sem testes cobrindo seus cenários.

---

## O que é proibido

```dart
// ❌ PROIBIDO — setup compartilhado entre testes
late HomeScreen screen;

setUp(() {
  screen = HomeScreen();
});

// ❌ PROIBIDO — contexto global
final mockTrack = Track(name: 'Test');

void main() {
  test('usa mock global', () {
    // depende de mockTrack definido fora
  });
}

// ❌ PROIBIDO — teste depende de outro ter rodado antes
test('segundo teste', () {
  // assume que 'primeiro teste' já criou dados
});
```

```dart
// ✅ CORRETO — cada teste cria o que precisa
test('botão INICIAR tem cor verde', () {
  final button = StartButton(color: AppColors.green);
  expect(button.color, equals(AppColors.green));
});

test('botão INICIAR tem label correto', () {
  final button = StartButton(label: 'INICIAR');
  expect(button.label, equals('INICIAR'));
});
```

---

## Estrutura de Pastas

```
lapzy-app/
├── test/
│   ├── unit/
│   │   ├── timing/
│   │   │   ├── delta_calculator_test.dart
│   │   │   └── lap_timer_test.dart
│   │   └── track/
│   │       ├── haversine_test.dart
│   │       ├── sector_snap_test.dart
│   │       └── direction_detector_test.dart
│   └── widget/
│       ├── home_screen_test.dart
│       ├── race_screen_test.dart
│       └── race_summary_screen_test.dart
└── integration_test/
    ├── home_to_race_test.dart
    ├── race_session_test.dart
    └── race_summary_test.dart
```

---

## Convenção de Nomenclatura

Cada arquivo de teste mapeia para uma US ou componente específico.
Cada `test()` ou `testWidgets()` descreve o cenário em português, espelhando o critério de aceite da US:

```dart
test('delta é positivo quando volta atual é mais rápida que a melhor', () { ... });
testWidgets('tela inicial exibe botão INICIAR centralizado', (tester) async { ... });
```

---

## Rodando Todos os Testes

```bash
# Unitários e widget
flutter test

# Integração (requer dispositivo conectado)
flutter test integration_test/ -d RXCXB09MSRN

# Tudo junto
flutter test && flutter test integration_test/ -d RXCXB09MSRN
```

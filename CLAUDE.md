# Lapzy — Instruções para o Claude Code

## Sobre o projeto

Lapzy é um app de cronometragem para kart, desenvolvido em Flutter/Dart para Android.
Cada decisão de design e arquitetura está documentada em `/docs`.

## Antes de codar

Leia sempre antes de qualquer implementação:
- `docs/principios.md` — filosofia e regras de design
- `docs/identidade.md` — paleta de cores e identidade visual
- `docs/lapzy_design_system.html` — componentes, tipografia, espaçamento
- `docs/testing.md` — estratégia de testes (obrigatório)

Para cada task, leia também os `refs:` indicados no `TASKS.md`.

## Fluxo de desenvolvimento

1. Leia o `TASKS.md` e identifique a task em Doing
2. Leia todos os `refs:` da task
3. Implemente a feature
4. Escreva os testes (veja Definição de Pronto abaixo)
5. Rode `flutter analyze` — zero issues obrigatório
6. Rode `flutter test` — zero falhas obrigatório
7. Rode `flutter test integration_test/ -d RXCXB09MSRN` — zero falhas obrigatório

## Definição de Pronto

Uma task só está concluída quando:

- [ ] Feature implementada conforme spec dos `refs:`
- [ ] Cores seguem exatamente o design system (sem aproximações)
- [ ] Testes unitários cobrem toda lógica de negócio
- [ ] Testes de widget cobrem todos os estados visuais relevantes
- [ ] Testes de integração cobrem todos os cenários da US
- [ ] `flutter analyze` retorna zero issues
- [ ] `flutter test` retorna zero falhas

Nunca mova uma task para Done sem todos os itens acima satisfeitos.

## Regras de teste

Seguir rigorosamente `docs/testing.md`. Resumo das regras inegociáveis:

- Cada teste é completamente independente
- Nenhum setup compartilhado entre testes
- Nenhum contexto global
- Testes de integração são obrigatórios — não são opcionais
- Cada critério de aceite da US vira um cenário de teste

## Regras de design

- Nunca usar cores fora da paleta definida em `docs/identidade.md`
- Laranja `#FF6D00` é exclusivo da marca — nunca usar em UI (exceto S3 como cor funcional de setor)
- Interface deve ser legível a 60cm de distância
- Máximo de 2 toques para qualquer ação

## Stack

- Flutter 3.41.7 / Dart
- Android (dispositivo de teste: Samsung A35, ID RXCXB09MSRN)
- Mapas: google_maps_flutter
- GPS: geolocator (LocationAccuracy.best)
- Assets SVG: flutter_svg

## Estrutura de pastas

```
lapzy-app/
├── CLAUDE.md           ← este arquivo
├── TASKS.md            ← kanban do projeto
├── docs/               ← fonte de verdade de toda documentação
├── lib/
│   └── screens/        ← uma screen por tela
├── test/
│   ├── unit/           ← lógica pura
│   └── widget/         ← widgets isolados
└── integration_test/   ← fluxos completos
```

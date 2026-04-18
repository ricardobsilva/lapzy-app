# Lapzy — Fluxo Principal

## Jornada Core

```
Abrir app
  └── Tela inicial
        └── [1 toque] INICIAR
              └── Seleção de pista (bottom sheet)
                    └── Tela de corrida (landscape)
                          └── [1 toque] FINALIZAR
                                └── Resumo da corrida
                                      └── Histórico
```

## Login

- **Opcional** — nunca bloqueia início de corrida
- Provedor: Google Sign-In
- Sugerido apenas em momentos estratégicos:
  - Após finalizar corrida ("Salve seu resultado")
  - Ao acessar Histórico
  - Ao acessar Ranking
- Nunca exibir modal de login antes de INICIAR

## Histórico

- Acessível pela tela inicial
- Lista de corridas anteriores
- Requer login para sincronizar na nuvem
- Funciona offline/local sem login

## Ranking

- Requer login
- Filtrado por pista
- Exibe melhor volta, não tempo total

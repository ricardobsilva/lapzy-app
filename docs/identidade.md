# Lapzy — Identidade Visual

## Nome
**Lapzy**
- Curto, moderno, contém "lap" (volta)
- Estilo app de performance

## Paleta de Cores

| Cor | Uso | Observação |
|---|---|---|
| 🟠 Laranja | Marca / logo | Apenas identidade, não usar em UI |
| 🟢 Verde | Ação principal | INICIAR, delta positivo, PR (personal record) |
| 🟣 Roxo | Melhor volta | Destaque especial, usar com parcimônia |
| 🔴 Vermelho | Alerta / encerrar | FINALIZAR, delta negativo, erros |

## Cores dos Setores

| Setor | Hex | Tipo |
|---|---|---|
| S1 | `#00B0FF` | Fixa |
| S2 | `#FFD600` | Fixa |
| S3 | `#FF6D00` | Fixa |
| S4+ | Gerada dinamicamente | Ver regra abaixo |

**Regra para S4 em diante**
- A cor é gerada no momento de criação da pista e persistida junto com ela
- Critério: tom livre, mas sempre com boa legibilidade sobre fundo escuro (`#0A0A0A`)
- A mesma cor é reutilizada em todas as telas que exibem aquele setor: tela de corrida, resumo pós-corrida e bottom sheet de detalhe de volta
- Cores geradas não devem colidir com as cores funcionais do sistema (verde `#00E676`, roxo `#BF5AF2`, vermelho `#FF3B30`)

## Estilo
- Esportivo e moderno
- Inspirado em apps de performance (F1, Strava, etc.)
- Dark mode como padrão (uso em pista, sol, capacete)
- Tipografia grande e bold nas informações críticas

## Tom de Voz
- Direto, sem texto desnecessário
- Labels curtos (INICIAR, não "Iniciar Corrida Agora")
- Sem onboarding prolixo

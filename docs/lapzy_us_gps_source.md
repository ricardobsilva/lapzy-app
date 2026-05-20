# Lapzy — US: Seleção de Fonte GPS

## User Story

> **Como** piloto de kart amador,  
> **quero** que o app detecte e use automaticamente o GPS externo que eu já pareei,  
> **para que** eu não precise configurar nada antes de cada corrida.

---

## Contexto

O Lapzy passará a suportar dispositivos GPS externos (dedicados), conectáveis via **Bluetooth** ou **USB-C**, além do GPS interno do celular. O piloto configura o dispositivo uma vez; o app lembra a preferência e a aplica automaticamente em sessões futuras.

---

## Decisões fechadas

**Comportamento padrão**
- O app detecta dispositivos GPS pareados e exibe um **banner passivo** na tela inicial quando um externo está ativo
- O banner pulsa suavemente para indicar conexão viva — não é um alerta, é status
- Toque no banner abre as configurações de Fonte GPS
- Nenhum passo é adicionado ao fluxo crítico INICIAR → pista → corrida

**Persistência**
- A escolha de dispositivo é salva localmente e reutilizada em todas as sessões seguintes
- Pode ser alterada a qualquer momento via banner ou via perfil/configurações

**Tela de configuração (Fonte GPS)**
- Seção "Ativo" — read-only, mostra o dispositivo em uso no momento
- Seção "Dispositivos disponíveis" — lista de GPS detectados + GPS interno
- GPS interno (celular) sempre presente como fallback, nunca desabilitado
- Dispositivo USB-C: exibido como desabilitado quando nada está conectado; ativa automaticamente ao plugar
- Scan Bluetooth roda em background enquanto a tela está aberta
- Confirmação explícita via botão "USAR ESTE GPS" para aplicar a troca

**Conexões suportadas**
| Tipo | Badge | Cor |
|------|-------|-----|
| Bluetooth | BT | `#00B0FF` |
| USB-C | USB | `#FFD600` |
| GPS interno | OK | `#00E676` |

---

## Critérios de aceite

- [ ] Banner aparece na tela inicial quando um GPS externo Bluetooth está conectado e ativo
- [ ] Banner aparece na tela inicial quando um GPS externo USB-C está conectado e ativo
- [ ] Banner **não aparece** quando o GPS interno é a fonte ativa (estado padrão silencioso)
- [ ] Toque no banner navega para a tela de Fonte GPS
- [ ] Tela de Fonte GPS exibe corretamente: seção Ativo + lista de disponíveis
- [ ] Dispositivo USB-C aparece como desabilitado quando nenhum cabo está conectado
- [ ] Dispositivo USB-C ativa automaticamente ao conectar o cabo (sem reiniciar a tela)
- [ ] Seleção confirmada por "USAR ESTE GPS" persiste entre sessões (SharedPreferences ou equivalente)
- [ ] GPS interno sempre disponível como fallback — nunca desabilitado, nunca oculto
- [ ] Scan BT ativo enquanto a tela de Fonte GPS estiver aberta; para ao sair

---

## Fora de escopo (v1)

- Configuração por pista (mesmo GPS para todas as pistas na v1)
- Suporte a múltiplos GPS simultâneos
- Fusão de dados GPS (interno + externo combinados)
- Diagnóstico de qualidade de sinal na tela de corrida

---

## Arquivos relacionados

- Protótipo interativo: `lapzy_gps_source_proto.html`
- Design system: `lapzy_design_system.html`
- Fluxo principal: `fluxo.md`
- Tela inicial: `lapzy_tela_inicial.md`

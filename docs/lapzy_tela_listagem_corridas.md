# Lapzy — Tela Listagem de Corridas

## Decisões fechadas

**Estrutura**
- Acesso via ícone de histórico (relógio) na tela inicial — sem alteração na home
- Top bar: botão voltar (‹) à esquerda · label "CORRIDAS" ao centro
- Ordenação por data decrescente (mais recente no topo)
- Cada item exibe: nome do circuito + data + hora
- Toque em qualquer item leva ao resumo da corrida correspondente

**Estado vazio**
- Mensagem humana: "Sua primeira corrida vai aparecer aqui. Que tal aquecer o motor?"
- Botão ghost verde "INICIAR CORRIDA" leva de volta ao fluxo principal

---

## Estado: Com registros

```svg
<svg viewBox="0 0 390 844" xmlns="http://www.w3.org/2000/svg" width="390" height="844" role="img">
  <title>Lapzy — Listagem de Corridas</title>
  <rect width="390" height="844" fill="#0A0A0A"/>
  <text x="20" y="26" fill="rgba(255,255,255,0.4)" font-family="monospace" font-size="12">9:41</text>
  <text x="370" y="26" text-anchor="end" fill="rgba(255,255,255,0.4)" font-family="monospace" font-size="12">●●●</text>
  <text x="20" y="66" fill="rgba(255,255,255,0.5)" font-family="monospace" font-size="18">‹</text>
  <text x="195" y="68" text-anchor="middle" fill="rgba(255,255,255,0.9)" font-family="monospace" font-size="14" font-weight="700" letter-spacing="2">CORRIDAS</text>
  <line x1="20" y1="82" x2="370" y2="82" stroke="rgba(255,255,255,0.06)" stroke-width="1"/>
  <rect x="20" y="98" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.07)" stroke-width="1"/>
  <text x="36" y="122" fill="#FFFFFF" font-family="monospace" font-size="14" font-weight="700">Kartódromo Granja Viana</text>
  <text x="36" y="144" fill="rgba(255,255,255,0.35)" font-family="monospace" font-size="11">12 abr 2026 · 14:32</text>
  <text x="362" y="134" text-anchor="end" fill="rgba(255,255,255,0.18)" font-family="monospace" font-size="20">›</text>
  <rect x="20" y="172" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.06)" stroke-width="1"/>
  <text x="36" y="196" fill="rgba(255,255,255,0.85)" font-family="monospace" font-size="14" font-weight="700">Pista do Sul Racing</text>
  <text x="36" y="218" fill="rgba(255,255,255,0.3)" font-family="monospace" font-size="11">03 abr 2026 · 09:15</text>
  <text x="362" y="208" text-anchor="end" fill="rgba(255,255,255,0.15)" font-family="monospace" font-size="20">›</text>
  <rect x="20" y="246" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.06)" stroke-width="1"/>
  <text x="36" y="270" fill="rgba(255,255,255,0.85)" font-family="monospace" font-size="14" font-weight="700">Speed Park Interlagos</text>
  <text x="36" y="292" fill="rgba(255,255,255,0.3)" font-family="monospace" font-size="11">28 mar 2026 · 16:48</text>
  <text x="362" y="282" text-anchor="end" fill="rgba(255,255,255,0.15)" font-family="monospace" font-size="20">›</text>
  <rect x="20" y="320" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.06)" stroke-width="1"/>
  <text x="36" y="344" fill="rgba(255,255,255,0.85)" font-family="monospace" font-size="14" font-weight="700">Kartódromo Ayrton Senna</text>
  <text x="36" y="366" fill="rgba(255,255,255,0.3)" font-family="monospace" font-size="11">15 mar 2026 · 11:05</text>
  <text x="362" y="356" text-anchor="end" fill="rgba(255,255,255,0.15)" font-family="monospace" font-size="20">›</text>
  <rect x="20" y="394" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
  <text x="36" y="418" fill="rgba(255,255,255,0.7)" font-family="monospace" font-size="14" font-weight="700">Kartódromo Granja Viana</text>
  <text x="36" y="440" fill="rgba(255,255,255,0.25)" font-family="monospace" font-size="11">02 mar 2026 · 08:20</text>
  <text x="362" y="430" text-anchor="end" fill="rgba(255,255,255,0.12)" font-family="monospace" font-size="20">›</text>
  <rect x="20" y="468" width="350" height="64" rx="10" fill="#141414" stroke="rgba(255,255,255,0.04)" stroke-width="1" opacity="0.4"/>
  <text x="36" y="492" fill="rgba(255,255,255,0.5)" font-family="monospace" font-size="14" font-weight="700">Pista do Sul Racing</text>
  <text x="36" y="514" fill="rgba(255,255,255,0.2)" font-family="monospace" font-size="11">18 fev 2026 · 15:00</text>
  <defs>
    <linearGradient id="fadeList" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0A0A0A" stop-opacity="0"/>
      <stop offset="100%" stop-color="#0A0A0A" stop-opacity="1"/>
    </linearGradient>
  </defs>
  <rect x="0" y="500" width="390" height="80" fill="url(#fadeList)"/>
  <rect x="148" y="820" width="94" height="4" rx="2" fill="rgba(255,255,255,0.12)"/>
</svg>
```

## Estado: Vazio (sem corridas)

```svg
<svg viewBox="0 0 390 844" xmlns="http://www.w3.org/2000/svg" width="390" height="844" role="img">
  <title>Lapzy — Listagem de Corridas (vazia)</title>
  <rect width="390" height="844" fill="#0A0A0A"/>
  <text x="20" y="26" fill="rgba(255,255,255,0.4)" font-family="monospace" font-size="12">9:41</text>
  <text x="370" y="26" text-anchor="end" fill="rgba(255,255,255,0.4)" font-family="monospace" font-size="12">●●●</text>
  <text x="20" y="66" fill="rgba(255,255,255,0.5)" font-family="monospace" font-size="18">‹</text>
  <text x="195" y="68" text-anchor="middle" fill="rgba(255,255,255,0.9)" font-family="monospace" font-size="14" font-weight="700" letter-spacing="2">CORRIDAS</text>
  <line x1="20" y1="82" x2="370" y2="82" stroke="rgba(255,255,255,0.06)" stroke-width="1"/>
  <circle cx="195" cy="330" r="38" fill="none" stroke="rgba(255,255,255,0.07)" stroke-width="2"/>
  <circle cx="195" cy="332" r="24" fill="none" stroke="rgba(255,255,255,0.12)" stroke-width="1.5"/>
  <line x1="195" y1="322" x2="195" y2="332" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="195" y1="332" x2="202" y2="337" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="189" y1="312" x2="195" y2="308" stroke="rgba(255,255,255,0.08)" stroke-width="2" stroke-linecap="round"/>
  <line x1="201" y1="312" x2="195" y2="308" stroke="rgba(255,255,255,0.08)" stroke-width="2" stroke-linecap="round"/>
  <text x="195" y="402" text-anchor="middle" fill="rgba(255,255,255,0.7)" font-family="monospace" font-size="15" font-weight="700">Nenhuma corrida ainda.</text>
  <text x="195" y="432" text-anchor="middle" fill="rgba(255,255,255,0.3)" font-family="monospace" font-size="12">Sua primeira corrida vai aparecer aqui.</text>
  <text x="195" y="452" text-anchor="middle" fill="rgba(255,255,255,0.3)" font-family="monospace" font-size="12">Que tal aquecer o motor?</text>
  <rect x="95" y="484" width="200" height="48" rx="10" fill="rgba(0,230,118,0.08)" stroke="rgba(0,230,118,0.25)" stroke-width="1"/>
  <text x="195" y="514" text-anchor="middle" fill="#00E676" font-family="monospace" font-size="13" font-weight="700" letter-spacing="2">INICIAR CORRIDA</text>
  <rect x="148" y="820" width="94" height="4" rx="2" fill="rgba(255,255,255,0.12)"/>
</svg>
```

# Lapzy — Tela Inicial

## Decisões fechadas

**Estrutura**
- Botão INICIAR centralizado vertical e horizontalmente — elemento dominante
- Top bar minimalista: ícone histórico (outline circular) à esquerda · logo LAPZY ao centro · ícone perfil (outline circular) à direita
- Sem cards, retângulos de fundo ou navegação adicional na home
- Tagline "CRONOMETRAGEM DE KART" acima do botão, opacidade baixa
- Hint "selecione a pista após iniciar" abaixo do botão
- Fundo limpo `#0A0A0A` com glow verde sutil atrás do botão
- Sem grid, sem watermark, sem ranking

**O que foi descartado e por quê**
- Ranking removido da home — não essencial no fluxo principal
- Grid de fundo removido — poluição visual sem função
- Cards/retângulos nos ícones removidos — quebravam o clean

---

## Protótipo

```svg
<svg viewBox="0 0 390 844" xmlns="http://www.w3.org/2000/svg" width="390" height="844" role="img">
  <title>Lapzy — Tela Inicial</title>
  <defs>
    <radialGradient id="glowGreen" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#00E676" stop-opacity="0.13"/>
      <stop offset="100%" stop-color="#00E676" stop-opacity="0"/>
    </radialGradient>
    <filter id="softBlur">
      <feGaussianBlur stdDeviation="32"/>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="390" height="844" fill="#0A0A0A"/>

  <!-- Glow centrado no botão -->
  <ellipse cx="195" cy="422" rx="210" ry="140" fill="url(#glowGreen)" filter="url(#softBlur)"/>

  <!-- Status bar -->
  <text x="20" y="26" fill="rgba(255,255,255,0.45)" font-family="monospace" font-size="12">9:41</text>
  <text x="370" y="26" text-anchor="end" fill="rgba(255,255,255,0.45)" font-family="monospace" font-size="12">●●●</text>

  <!-- Logo topo centralizado -->
  <text x="195" y="72" text-anchor="middle" font-family="monospace" font-size="22" font-weight="700" letter-spacing="2">
    <tspan fill="#FFFFFF">LAP</tspan><tspan fill="#FF6D00">ZY</tspan>
  </text>

  <!-- Ícone perfil — canto superior direito -->
  <circle cx="358" cy="60" r="14" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.2"/>
  <circle cx="358" cy="57" r="5" fill="rgba(255,255,255,0.5)"/>
  <path d="M347,72 Q347,66 358,66 Q369,66 369,72" fill="rgba(255,255,255,0.5)"/>

  <!-- Ícone histórico — canto superior esquerdo -->
  <circle cx="32" cy="60" r="14" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.2"/>
  <circle cx="32" cy="60" r="7" fill="none" stroke="rgba(255,255,255,0.5)" stroke-width="1.2"/>
  <line x1="32" y1="55" x2="32" y2="60" stroke="rgba(255,255,255,0.5)" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="32" y1="60" x2="35" y2="62" stroke="rgba(255,255,255,0.5)" stroke-width="1.2" stroke-linecap="round"/>

  <!-- Tagline -->
  <text x="195" y="390" text-anchor="middle" font-family="monospace" font-size="10" font-weight="700" letter-spacing="3.5" fill="rgba(255,255,255,0.35)">CRONOMETRAGEM DE KART</text>

  <!-- INICIAR -->
  <rect x="75" y="406" width="240" height="64" rx="14" fill="#00E676"/>
  <text x="195" y="447" text-anchor="middle" font-family="monospace" font-size="18" font-weight="700" letter-spacing="4" fill="#000000">INICIAR</text>

  <!-- Hint -->
  <text x="195" y="494" text-anchor="middle" font-family="monospace" font-size="10" fill="rgba(255,255,255,0.28)" letter-spacing="1">selecione a pista após iniciar</text>

  <!-- Bottom indicator -->
  <rect x="148" y="820" width="94" height="4" rx="2" fill="rgba(255,255,255,0.15)"/>
</svg>
```
